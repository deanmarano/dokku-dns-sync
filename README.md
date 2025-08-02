# dokku dns [![Build Status](https://img.shields.io/github/actions/workflow/status/dokku/dokku-dns/ci.yml?branch=master&style=flat-square "Build Status")](https://github.com/dokku/dokku-dns/actions/workflows/ci.yml?query=branch%3Amaster) [![IRC Network](https://img.shields.io/badge/irc-libera-blue.svg?style=flat-square "IRC Libera")](https://webchat.libera.chat/?channels=dokku)

A dns plugin for dokku. Currently defaults to installing [busybox 1.37.0-uclibc](https://hub.docker.com/_/busybox/).

## Requirements

- dokku 0.19.x+
- docker 1.8.x

## Installation

```shell
# on 0.19.x+
sudo dokku plugin:install https://github.com/dokku/dokku-dns.git --name dns
```

## Commands

```
dns:add-domains <app>    # add app domains to dns provider for management
dns:configure <provider> # configure or change the global dns provider
dns:provider-auth        # configure provider authentication for dns
dns:report <app>         # display DNS sync status and domain information for an app
dns:sync <app>           # synchronize DNS records for app
```

## Usage

Help for any commands can be displayed by specifying the command as an argument to dns:help. Plugin help output in conjunction with any files in the `docs/` folder is used to generate the plugin documentation. Please consult the `dns:help` command for any undocumented commands.

### Basic Usage

### add app domains to dns provider for management

```shell
# usage
dokku dns:add-domains <app>
```

Add app domains to `DNS` provider for management:

```shell
dokku dns:add-domains nextcloud
dokku dns:add-domains nextcloud example.com api.example.com
```

By default, adds all domains configured for the app optionally specify specific domains to add to `DNS` management this registers domains with the `DNS` provider but doesn`t sync records yet use `dokku dns:sync` to update `DNS` records:

### configure or change the global dns provider

```shell
# usage
dokku dns:configure <provider>
```

Configure the global `DNS` sync provider:

```shell
dokku dns:configure [aws|cloudflare]
```

This sets up or changes the `DNS` provider for all `DNS` synchronization. If no provider is specified, defaults to `$DNS_SYNC_DEFAULT_PROVIDER` if provider is already configured, this will change to the new provider after configuration, use other commands to: - configure credentials: dokku dns:provider-auth - sync an app: dokku dns:sync myapp:

### Disabling `docker image pull` calls

If you wish to disable the `docker image pull` calls that the plugin triggers, you may set the `DNS_DISABLE_PULL` environment variable to `true`. Once disabled, you will need to pull the service image you wish to deploy as shown in the `stderr` output.

Please ensure the proper images are in place when `docker image pull` is disabled.
