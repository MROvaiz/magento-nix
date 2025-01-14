{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = {
    self,
    nixpkgs,
    devenv,
    systems,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    packages = forEachSystem (system: {
      devenv-up = self.devShells.${system}.default.config.procfileScript;
      devenv-test = self.devShells.${system}.default.config.test;
    });

    devShells =
      forEachSystem
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            ({config, ...}: {
              # packages
              packages = with pkgs; [
                git
                gnupatch
                curl
                nss_latest
                nssTools
                openssl
              ];

              # process-compose
              process.manager.implementation = "process-compose";

              # flake shell script
              enterShell = ''
                sudo sysctl -w net.ipv4.ip_unprivileged_port_start=0
                sudo sysctl -w net.core.rmem_max=7500000
                sudo sysctl -w net.core.wmem_max=7500000
              '';

              # /etc/hosts entry
              hosts = {
                "dev.example.local" = "127.0.0.1"; # testing hosts
                "dev.magento2.local" = "127.0.0.1";
              };

              # php setup with fpm
              languages.php = {
                enable = true;
                package = pkgs.php82.buildEnv {
                  extensions = {
                    all,
                    enabled,
                  }:
                    with all; enabled ++ [xdebug xsl redis];
                  extraConfig = ''
                    memory_limit = -1
                    display_errors = On
                    display_startup_errors = On
                    error_reporting=E_ALL
                    xdebug.mode = coverage,debug
                    opcache.memory_consumption = 256M
                    opcache.interned_strings_buffer = 20
                    sendmail_path = ${pkgs.mailpit}/bin/mailpit sendmail -S 127.0.0.1:1025
                  '';
                };
                fpm.pools.web = {
                  settings = {
                    "clear_env" = "no";
                    "pm" = "dynamic";
                    "pm.max_children" = 20;
                    "pm.start_servers" = 5;
                    "pm.min_spare_servers" = 1;
                    "pm.max_spare_servers" = 5;
                  };
                };
              };

              services = {
                # elasticsearch
                opensearch.enable = true;

                # email setup
                mailpit.enable = true;

                # mysql monitor
                adminer.enable = true;

                # redis caches
                redis.enable = true;

                # rabbitmq messaging queue
                rabbitmq.enable = true;

                # mysql database
                mysql = {
                  enable = true;
                  package = pkgs.mariadb_106;
                  settings = {
                    mysqld = {
                      port = 3306;
                      innodb_buffer_pool_size = "2G";
                      table_open_cache = "2048";
                      sort_buffer_size = "8M";
                      join_buffer_size = "8M";
                      query_cache_size = "256M";
                      query_cache_limit = "2M";
                    };
                  };
                  initialDatabases = [{name = "magento2";}];
                  ensureUsers = [
                    {
                      name = "magento2";
                      password = "magento2";
                      ensurePermissions = {"magento2.*" = "ALL PRIVILEGES";};
                    }
                  ];
                };

                # caddy host
                caddy = {
                  enable = true;
                  ca = "https://acme-staging-v02.api.letsencrypt.org/directory";
                  # All Virtual Hosts
                  virtualHosts = {
                    # testing SSL
                    "dev.example.local" = {
                      extraConfig = ''
                        tls internal
                        respond "Hello, world from dev.example.local!"
                      '';
                    };
                    # main host
                    "dev.magento2.local" = {
                      extraConfig = ''
                        root * magento2/pub
                        php_fastcgi unix/${config.languages.php.fpm.pools.web.socket}
                        file_server
                        tls internal

                        @blocked {
                          path /media/customer/* /media/downloadable/* /media/import/* /media/custom_options/* /errors/*
                        }
                        respond @blocked 403

                        @notfound {
                          path_regexp reg_notfound \/\..*$|\/errors\/.*\.xml$|theme_customization\/.*\.xml
                        }
                        respond @notfound 404

                        @staticPath path_regexp reg_static ^/static/(version\d*/)?(.*)$
                        handle @staticPath {
                          @static file /static/{re.reg_static.2}
                          rewrite @static /static/{re.reg_static.2}
                          @dynamic not file /static/{re.reg_static.2}
                          rewrite @dynamic /static.php?resource={re.reg_static.2}
                        }

                        @mediaPath path_regexp reg_media ^/media/(.*)$
                        handle @mediaPath {
                          @static file /media/{re.reg_media.1}
                          rewrite @static /media/{re.reg_media.1}
                          @dynamic not file /media/{re.reg_media.1}
                          rewrite @dynamic /get.php?resource={re.reg_media.1}
                        }
                      '';
                    };
                  };
                };
              };
            })
          ];
        };
      });
  };
}
