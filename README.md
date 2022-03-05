## Background

The scope of this project is a special interest forum that uses [Invision Community (IC)](https://invisioommunity.com/) as its forum engine; this is served on a bare / self-managed VP that I've rehosted a few times over the years, mainly because the storage requirement have grown and we need to use a supported LTS stack.  The current 6-core VPS with SSD storage costs less than the 2-core + HDD VPS that we initially commission 6 years ago, and is a lot less than that of using a managed IC service.

I have provided pro-bono SysAdmin and developer contributions to various not-for-profit sites and open-source projects, but I am now retired and I am winding down these activities.  Future SysAdmin continuity for this forum is a concern, and because I have used Docker for other projects, I have decided to move to using a GitHub registered Docker stack for the new Ubuntu 20.04-LTS server and to simplify migration.

This server has been kept as a bare Docker, with the only host open port SSH access by public key, and with the `docker.io`, `docker-compose` and `git` packages installed as well as a few useful utilities. I have a single docker compose project (as per this GitHub repo) that can spin up separate LAMP stacks for our production and test subdomains. Using disjoint ports means that we only need one external IP address and no reverse proxy.
-  *forum*.  Open ports 80 (for port forwarding), 443
-  *test*.   Open ports 8080 (for port forwarding), 4443

A major advantage of Docker is that the setup and configuration is encapsulated in a single directory hierarchy, comprising a few dozen files, and under 1K lines of script, config and comments; all controlled through Git.

So long as the hosting server has `git` and `docker`  installed, then anyone with access to the forum backup files, and copies of the `.env` and `.secret` contents could install a local copy of the forum with a couple of commands.  This makes it a lot easier for another SysAdmin so understand how our forum's server is configured.

## Design Decisions

*  This configuration is openly accessible via GitHub, although I have followed the usual practice of excluding the few dozen lines of `.env` and `.secret` content, which needs to be shared privately.
*  I developed this Docker service stack in two iterations:
    *  The first was to simplify the forum migration from a legacy IPBoard 4.4.6 + PHP 7.2 + MySQL 5.7 to current versions (and archived on the `Gen 1` branch ).
    *  This second is a stripped down rework that only supports current S/W versions; it is maintained on this `main` branch.
*  Docker's own official Mysql and Alpine images are used.
*  All running services follow the common Docker practice of presenting a single service which runs as a foreground process (though some execute load-balancing child processes), with the Docker runtime doing the daemonisation.
*  The `mysql` service uses the offical `mysql` image because this includes a complex startup logic to handle recovery for unscheduled shutdown, DB upgrades, etc., and so I have kept this very much as 'out of the can'.
*  The remaining four services use a shared image based on the official `alpine:3.15` image that is build as part of the `hk` service
    *  by aligning the `PID` and `GID` allocations for `www-data` to those of the host to simplify UID based access across volumes
    *  by installing the relevant Alpine packages to support `php-cli` and `php-fpm` (together with the PHP modules needed to run the IC Suite), `apache2`(together with the apache2 modules needed to run the website), `certbot`, `redis-server` and `crond`.
    *  The Docker Compose "up" function spins up four containers based on this one Alpine image and these are personalised as discussed in the following section to create the the `apache2`, `hk`, `php` and `redis` services.
*  I have adopted a mixed logging strategy has been adopted:
    *  High volume informational logs (such as the Apache2 access logs) are written to a persistent shared `/var/log` volume (as these are only occasionally mined for hacking forensics).
    *  Genuine errors are passed to the Docker logging system.
*  Timed events (such as backup and log rotation) are orchestrated by a `crontab` in the dedicated housekeeping `hk` service. See the files `docker-callback-reader.service` and `docker-callback-reader` in the `extensions` tree for how this is implemented.
*  The Docker application presents a minimal security surface.  Hence intra-container communication is carried out over a private `ipam` network and only the HTTP and HTTPS ports exposed to the host.

## Customising the Service Context

*  Persistent data is mapped through shared Docker volumes.
*  Configuration Files and any bash scripts are `readonly` mapped into a `/usr/local/` directory.
*  Any service-specific action scripts are bound by mapping the host `<service>/bin` folder to `/usr/local/sbin`.
*  A common Docker Entrypoint script `docker_entrypoint.sh` script to handle container spin-up and customisation. This script includes a `case ${HOSTNAME}` dispatcher to handle service specific startup.
  *  In the case of `mysql`, this is mounted in `/usr/local/sbin/` also exec chains onto the standard mysql `/usr/local/bin/docker_entrypoint.sh` to do its recovery and upgrade logic.
  *  For the other containers, this is mounted in `/usr/local/bin/` to allow a scripts volume to be mounted at `sbin`.
  *  Path-based execution of scripts enables each service to override image defaults, because `/usr/local/sbin/` is ahead of `/usr/local/bin/` on the search `PATH`.
*  This script also checks for a `/usr/local/sbin/startup_hook.sh` and executes this if present.
*  Services can also tailor the service configuration by mapping any `conf` files or subfolders as `read-only` volumes directly into the relevant `/etc` locations. I use this approach for the `httpd` service where I have swapped out the main Apache2 `conf` files.
*  Alternively these can be mapped into  `/usr/local/etc` and the startup hook script can move these as needed into `etc` or use inline `sed` commands to edit the package installed `conf` files.  IMO, this last approach is better than "cloning and edit" of standard `conf`, since it is far clearer what changes to standard have been made.  See the various `startup_hook.sh` files in the code tree for how this is implemented.

Note that the hidden `.env`, and `.secret` files are not under change control and are excluded from the github repository, but allow installion-specific secrets to be passed to running stach. `env.default-template` documents how to set these up.

##  Still TODO

(Most of these are just script migration from the exist prod service )
* Move php-fpm access log to /var/logs
* Implement logrotation
* Implement the nightly backup

## See Also

*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributers) comments on open issues.
