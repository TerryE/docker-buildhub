## Background

The scope of this project is a special interest forum that uses [Invision Community (IC)](https://invisioommunity.com/) as its forum engine; this is served on a bare / self-managed VP that I've rehosted a few times over the years, mainly because the storage requirement have grown and we need to use a supported LTS stack.  The current 6-core VPS with SSD storage costs less than the 2-core + HDD VPS that we initially commissioned 6 years ago, and is a lot less than that of using a managed IC service.

I have provided pro-bono SysAdmin and developer contributions to various not-for-profit sites and open-source projects, but I am now retired and I am winding down these activities.  Future SysAdmin continuity for this forum is a concern, and because I have used Docker for other projects, I have decided to move to using a GitHub registered Docker stack for the new Ubuntu 20.04-LTS server and to simplify migration.

This server has been kept as a pretty bare Docker host with the `docker.io`, `docker-compose` and `git` packages installed as well as a few useful utilities.
The only internet accessible service / port on the underlying host is for SSH access by public key.  I currently have a single Docker Compose project (as per this GitHub repo) that can spin up separate LAMP stacks for our production and test subdomains. Using disjoint ports means that we only need one external IP address and no reverse proxy.
-  *forum*.  Open ports 80 (for port forwarding), 443
-  *test*.   Open ports 8080 (for port forwarding), 4443

A major advantage of Docker is that the setup and configuration is encapsulated in a single directory hierarchy, comprising a few dozen files, and under 1K lines of script, config and comments; all controlled through Git.

So long as the hosting server has `git` and `docker`  installed, then anyone with access to the forum backup files (and copies of the `.env` and `.secret` contents) could install a local copy of the forum with a couple of commands.  This makes it a lot easier for another SysAdmin to understand how our forum's server is configured.  Alternatively anyone else who wants to self-host the Invision community suite can by a bare VPS, install docker and use this project to configure their own service.

## Design Decisions

*  This configuration is openly accessible via GitHub, although I have followed the usual practice of excluding the few dozen lines of `.env` and `.secret` content, which need to be shared privately.
*  I developed this Docker service stack in two iterations:
    *  The first was to simplify the forum migration from a legacy IPBoard 4.4.6 + PHP 7.2 + MySQL 5.7 to current versions (and is archived on the `Gen 1` branch ).
    *  This second is a stripped down rework that only supports current S/W versions; it is maintained on this `main` branch.
*  Docker's own official Mysql and Alpine images are used.
*  All running services follow the common Docker practice of presenting a single service which runs as a foreground process (though some execute load-balancing child processes), with the Docker runtime doing the daemonisation.
*  The `mysql` service uses the official `mysql` image because this includes a complex startup logic to handle recovery for unscheduled shutdown, DB upgrades, etc., and so I have kept this very much as 'out of the can'.
*  The remaining five services use a shared image based on the official `alpine:3.15` image that is build as part of the `hk` service
    *  by aligning the `PID` and `GID` allocations for `www-data` to those of the host to simplify UID based access across volumes
    *  by installing the relevant Alpine packages to support `php-cli` and `php-fpm` (together with the PHP modules needed to run the IC Suite), `apache2`(together with the apache2 modules needed to run the website), `certbot`, `crond`, `redis-server` and `sshd`.
    *  The Docker Compose "up" function spins up five containers based on this one Alpine image and these are personalised as discussed in the following section to create the `apache2`, `hk`, `php`, `redis` abd `sshd` services.
*  I have adopted a mixed logging strategy:
    *  High volume informational logs (such as the Apache2 access logs) are written to a persistent shared `/var/log` volume (as these are only occasionally mined for hacking forensics), with standard Linux log rotation.
    *  Genuine errors are passed to the Docker logging system.
*   The `sshd` service is mounted onto port 2222 and offers a single user `backups` with `/backups` as the home directory. This user is in group `www-data` and has group read access to the forum backups volume.  The purpose of this service is to allow authorised users (who are not sysAmins) public key read-only access to the backup folders for off-site duplication).
*  Timed events (such as backup and log rotation) are orchestrated by a `crontab` in the dedicated housekeeping `hk` service. See the files `docker-callback-reader.service` and `docker-callback-reader` in the `service` subdirectory for how this is implemented.
*  The Docker application presents a minimal security surface.  Hence intra-container communication is carried out over an internal network and only the HTTP, HTTPS and backup SSH ports are exposed to the host.

## Customising the Service Context

*  Persistent data is mapped through shared Docker volumes.
*  Each service is configured through its own `service` subfolder.  This contains two subfolders:
    *  `bin` contains any bash scripts that will be used to configure the service.  This folder is mapped read-only to `/usr/local/sbin` in the running service.  At a minimum this contains two scripts:
        *  `docker-entrypoint.sh` is the service-specific Docker entrypoint script; this handles any container spin-up and customisation.  It may also include runtime tailoring of the configuration by copying files from `/usr/local/conf` into the correct or by using `sed` to make indivual parameter changes to `/etc` files.  The final act of this script is to `exec` the service daemon with the correst start-up parameters.  (In the case of `mysql`, it exec chains into the standard mysql  image entrypoint to do the recovery and startup process.)
        *  `docker-service-callback.sh` is the captive standard target to implement any service-specific tasks as issued by the `docker-callback-reader`.  Someservices don't process any such events, so this is a placeholder file.
    *  `conf` contains any files that will be used to configure the service.  As small modifications are done by the startup script, this is only used when a config file completely replaces the standard default.  If this folder exists, it is mapped read-only to `/usr/local/conf` in the running service.

Note that the hidden `.env`, and `.secret` files are not under change control and are excluded from the github repository, but allow installation-specific secrets to be passed to running stack. `env.default-template` documents how to set these up.

## Logging

All services log startup to Docker.  Some services switch to `/var/log/<service>` for bulk logging.

| Service | Comment |
| ------- | ------- |
| hk      | Crond events are logged to /var/log/cron/ |
| httpd   | Accesses logged to /var/log/apache2, errors to Docker |
| php     | Accesses logged to /var/log/php |
| redis   | Notifications are logged to /var/log/redis |

The four services that use logging to /var/log all use the shared image.  Log rotation is done as a housekeeping task though in a couple of cases the postrotate trigger does a "flushlogs" callback the relevant service.

## Backup

Nightly backup is managed as a housekeeping function, and backups are written to the
backups volume.  The `sshd` service implements ssh access to a restricted account with
its home folder mapped to the backups volume.  This enables authorised users to `rsync`
the backups to a local offsite copy.

##  Still TODO

## See Also

*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributors) comments on open issues.
