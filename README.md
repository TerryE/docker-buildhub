## Background

The scope of this project is a special interest forum that uses [Invision Community (IC)](https://invisioncommunity.com/) as its forum engine.  The forum is hosted on a bare / self-managed virtual server (VS) that we've rehosted a few times over the years to accommodate forum growth and to use a supported service stack.  The current 6-core VS with SSD storage costs less than the 2-core + HDD VS that we initially commissioned 6 years ago, and is also significantly less than that of using a managed IC service.

I have provided pro-bono SysAdmin and developer contributions to various not-for-profit sites and open-source projects over the years.  However, I am now retired and am winding down these activities, so longer term sysAdmin continuity for this forum is a concern. I therefore decided to move to using a GitHub registered Docker stack for the new Ubuntu 20.04-LTS VS server both to simplify migration, and to bring its configuration under tight configuration control.

This hosting VS has been configured as a bare Docker host, that is with the `docker.io`, `docker-compose` and `git` packages installed as well as a few useful utilities.
The only internet accessible service / port to the underlying host is for SSH access by public key.  A single Docker Compose project is currently implemented (using this GitHub repository) that can be used to spin up separate LAMP stacks for our production and test subdomains; these use disjoint ports so that we only need one external IP address and no reverse proxy.
-  *forum*.  Open ports 80 (for port forwarding), 443
-  *test*.   Open ports 8080 (for port forwarding), 4443

A major advantage of Docker is that the setup and configuration is encapsulated in a single directory hierarchy, comprising a few dozen files, and about 1K lines of script, config and comments; all controlled through Git.

So long as the hosting server has `git` and `docker`  installed, then anyone with access to the forum backup files (and copies of the `.env` and `.secret` contents) could install a local copy of the forum with a couple of commands.  This makes it a lot easier for another SysAdmin to understand how our forum's server is configured.  Alternatively anyone else who wants to self-host the Invision Community Suite can buy a VS, install docker and use this project to configure their own service.

## Design Decisions

*  This configuration is openly accessible via GitHub, although I have followed the usual practice of excluding the few dozen lines of private `.env` and `.secret` content; these need to be shared privately.
*  I developed this Docker service stack in two iterations:
    *  The first was to simplify the forum migration from a legacy IPBoard 4.4.6 + PHP 7.2 + MySQL 5.7 to current versions (and is archived on the `Gen 1` branch ).
    *  This second was a stripped down rewrite based on lessons learnt from version one, but that only supports current S/W versions; this version is maintained on this `main` branch.
*  Docker's own official MySQL and Alpine images are used as a basis.
*  All running services follow the standard Docker practice of each container presenting a single service that runs as a foreground process (though some execute load-balancing child processes), with the Docker runtime implementing the daemon functionality.
*  The `mysql` service is based on the official MySQL image because this includes a complex startup logic to handle recovery for unscheduled shutdown, DB upgrades, etc., and so I have kept this very much as 'out of the can'.
*  The remaining services all use a single shared image based on the official `alpine:3.15` image that is build as part of the `hk` service:
    *  By installing the relevant Alpine packages to support `php-cli` and `php-fpm` (together with the PHP modules needed to run the IC Suite), `apache2`(together with the apache2 modules needed to run the website), `certbot`, `crond`, `redis-server` and `sshd`.
    *  By aligning the `PID` and `GID` allocations for `www-data` to those of the host to simplify UID based access across volumes
*  The Docker Compose "up" function creates five containers based on this one Alpine image and these are personalised as discussed in the following section to create the `apache2`, `hk`, `php`, `redis` and `sshd` services.
*  I have adopted a mixed logging strategy:
    *  High volume informational logs (such as the Apache2 access logs) are written to a persistent shared `/var/log` volume (as these are only occasionally mined for hacking forensics), with standard Linux log rotation.
    *  Genuine errors are passed to the Docker logging system.
*   The `sshd` service is mounted onto port 2222 and offers a single user `backups` with `/backups` as the home directory. This user is in group `www-data` and has group read access to the forum backups volume.  The purpose of this service is to allow authorised users (who are not sysAmins) public key read-only access to the backup folders for off-site duplication).
*  Timed events (such as backup and log rotation) are orchestrated by a `crontab` in the dedicated housekeeping `hk` service. See the files `docker-callback-reader` and `docker-callback-reader.service` in the `service` subdirectory for how this is implemented.
*  The Docker application presents a minimal security surface.  Hence inter-container communication is carried out over an internal network and only the HTTP, HTTPS and backup SSH ports are exposed to the host.

## Customising the Service Context

*  Persistent data is mapped through shared Docker volumes.
*  Each service is configured through its own `service` subfolder.  This contains two sub-folders:
    *   **`bin`** contains any bash scripts that will be used to configure the service.  This folder is mapped read-only to `/usr/local/sbin` in the running service.  At a minimum this contains two scripts:
        *  `docker-entrypoint.sh` is the service-specific Docker entrypoint script; this handles any container spin-up and customisation.  It may also include runtime tailoring of the configuration by copying files from `/usr/local/conf` into the correct `/etc` location, or by using `sed` to make individual parameter changes to `/etc` files.  The final act of this script is to `exec` the service daemon with the correct start-up parameters.  (In the case of `mysql`, it exec chains into the standard mysql image entrypoint to do the recovery and startup process.)
        *  `docker-service-callback.sh` is the captive standard target to implement any service-specific tasks as issued by the `docker-callback-reader`.  Someservices don't process any such events, so this is a placeholder file.
    *   **`conf`** contains any files that will be used to configure the service.  As small modifications are done by the startup script, this is typically only used when a config file completely replaces the standard default.  If this folder exists, it is mapped read-only to `/usr/local/conf` in the running service.

Note that the hidden `.env`, and `.secret` files are not under change control and are excluded from the github repository, but allow installation-specific secrets to be passed to running stack. `env.default-template` documents how to set these up.

## Logging

All services log startup to Docker.  Most services then switch to `/var/log/<service>` for bulk logging.

| Service | Comment |
| ------- | ------- |
| hk      | Crond events are logged to /var/log/cron/ |
| httpd   | Logged to `/var/log/apache2`, some errors to Docker. Certbot renewals to  `/var/log/letsencrypt` |
| mysql   | Low volume error reporting, so logged to Docker |
| php     | Logged to `/var/log/php` |
| redis   | Logged to `/var/log/redis` |
| sshd    | Logged to `/var/log/sshd` |

A shared volume is mapped to `/var/log` for all service containers, and are thus accessible from `hk`.  Log rotation is done as a cron task in the `hk`service`, though in a couple of cases the postrotate trigger does a "flushlogs" callback the relevant service.

## Backup

Nightly backup is also managed as a housekeeping function, and backups are written to the
backups volume.  The `sshd` service implements ssh access to a restricted account with
its home folder mapped to the backups volume.  This enables authorised users to `rsync`
the backups to a local offsite copy.

##  Still TODO

## See Also

*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributors) comments on open issues.
