# Nix Flake Magento

This Config is about magento development environment setup using nix flake.

### Prerequisite:
- [NixOS](https://nixos.org/) or Nix Package Manager(flake enable).
- [Devenv](https://devenv.sh) development environment.
- Magento System [Requirements](https://experienceleague.adobe.com/en/docs/commerce-operations/installation-guide/system-requirements) (only for understanding).

### Features:
1. PHP.
2. mariadb.
3. Redis.
4. OpenSearch. 
5. Xdebug.
6. [Mailpit](https://github.com/axllent/mailpit).
7. [Adminer](https://github.com/vrana/adminer).
8. [Caddy](https://github.com/caddyserver/caddy) with Local SSL certificate.
9. [RabbitMQ](https://github.com/rabbitmq/rabbitmq-server)(WIP).

## Installation:

### Install Nix/Devenv:
Install Nix and Devenv from [installation](https://devenv.sh/getting-started/), make sure to enable experimental features for flake.

### Clone Repository
- Clone the repo by: `git clone git@github.com:MROvaiz/magento-nix.git`

### Give permission for caddy for port 80 and 443:
On `enterShell` Run this, which give non-privileged user access for port 80, 443 and increase buffer size:
```bash
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=0
sudo sysctl -w net.core.rmem_max=7500000
sudo sysctl -w net.core.wmem_max=7500000
```
Or you can add in your NixOS config which runs on boot, ([unprivileged](https://discourse.nixos.org/t/what-is-the-correct-way-to-allow-binding-of-port-80-and-443/32037/7), [buffer-size](https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes) and [caddy-permission](https://github.com/cachix/devenv/issues/785)):
```nix
boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = false;
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
};
```

### Hosts Setup
add below, which gives write permission to `/etc/hosts` file (only for NixOS), [refer](https://github.com/cachix/devenv/issues/940).
```nix
environment.etc.hosts.mode = "0644";
```
hosts in `flake.nix`, will add entry in `/etc/hosts`
```nix
hosts = {
    "dev.magento2.local" = "127.0.0.1";
};
```
### Steps to start:
- Entering the Flake shell: `nix develop --no-pure-eval`.
- Start all services with `devenv up`.
- [Test SSL Host](https://github.com/NixOS/nixpkgs/issues/270297):
```bash
curl -k --resolve dev.magento2.local:443:127.0.0.1 https://dev.magento2.local
```

Note: Sometimes there is a problem with `/etc/hosts`. try deleting `.devenv/state/hostctl` once and `devenv up`, if `/etc/hosts` is not writing([sudo-permission](https://github.com/cachix/devenv/issues/940)).

## Get Open Source Magento:
- Make sure you have `~/.config/composer/auth.json` or `auth.json` in existing project (get the keys from magento marketplace).
- Run `composer install` for existing project. 
- Or get latest magento community edition: 
```bash
composer create-project --repository-url=https://repo.magento.com magento/project-community-edition magento2
``` 

## Magento install
```bash
php bin/magento setup:install \
--base-url=https://dev.magento2.local \
--cleanup-database \
--db-host=127.0.0.1 \
--db-name=magento2 \
--db-user=magento2 \
--db-password=magento2 \
--backend-frontname=admin \
--admin-firstname=admin \
--admin-lastname=admin \
--admin-email=admin@admin.com \
--admin-user=admin \
--admin-password=admin123 \
--language=en_US \
--currency=INR \
--timezone=Asia/Kolkata \
--use-rewrites=1 \
--search-engine=opensearch \
--opensearch-host=127.0.0.1 \
--opensearch-port=9200 \
--session-save-redis-host=127.0.0.1 \
--session-save-redis-port=6379 \
--session-save-redis-db=0 \
--cache-backend-redis-server=127.0.0.1 \
--cache-backend-redis-port=6379 \
--cache-backend-redis-db=1 \
--page-cache-redis-server=127.0.0.1 \
--page-cache-redis-port=6379 \
--page-cache-redis-db=2 
```

### Operations

disable 2fa(for now):
```bash
bin/magento module:disable Magento_TwoFactorAuth Magento_AdminAdobeImsTwoFactorAuth
```
update https configs(for now):
```bash
bin/magento config:set web/unsecure/base_url https://dev.magento2.local/ 
bin/magento config:set web/secure/base_url https://dev.magento2.local/ 
```

## Credits
Please find the initial config and idea [magento2-devenv](https://github.com/fballiano/magento2-devenv)(devenv use)
