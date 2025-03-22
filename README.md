\## Background

The scope of this project is a special interest forum that uses [Invision Community (IC)](https://invisioommunity.com/) as its forum engine.  The forum is hosted on a bare / self-managed virtual server (VS) that we've rehosted a few times over the years to accommodate forum growth and to use a supported service stack.  The current 6-core VS with SSD storage costs less than the 2-core + HDD VS that we initially commissioned 6 years ago. Self-management of a bare VS is 2-10× less than an equivalent managed VS or IC service.

I have provided pro-bono SysAdmin and developer contributions to various not-for-profit sites and open-source projects over the years.  However, I am now retired and am winding down these activities, so longer term sysAdmin continuity for this forum is a concern. I therefore decided to move to using a GitHub registered Docker stack for the new Ubuntu VS server both to simplify migration, and to bring its configuration under tight configuration control -- that is with the `docker.io`, `docker-compose` and `git` packages installed as well as a few useful utilities.

The only internet accessible service / port to the underlying host is for SSH access by public key.  A single Docker Compose project is currently implemented (using this GitHub repository) that can be used to spin up separate LAMP stacks for our production and test subdomains; these use disjoint ports so that we only need one external IP address and no reverse proxy.
-  *forum*.  Open ports 80 (for port forwarding), 443
-  *test*.   Open ports 8080 (for port forwarding), 4443 (currently stopped)

A major advantage of Docker is that the setup and configuration is encapsulated in a single directory hierarchy, comprising a few dozen files, and about 1K lines of script, config and comments; all controlled through Git.

So long as the hosting server has `git` and `docker` installed, then anyone with access to the forum backup files (and copies of the `.env` and `.secret` contents) could install a local copy of the forum with a couple of commands.  This makes it a lot easier for another SysAdmin to understand how our forum's server is configured.  Alternatively anyone else who wants to self-host the Invision Community Suite can buy a VS, install docker and use this project to configure their own service.

## Design Decisions

*  This configuration is openly accessible via GitHub, although I have followed the usual practice of excluding the few dozen lines of private `.env` and `.secret` content; these need to be shared privately.
*  I have developed this Docker service stack in three iterations:
    1.  The first was to simplify the forum migration from a legacy IPBoard 4.4.6 + PHP 7.2 + MySQL 5.7 to current versions (and is archived on the `Gen 1` branch ).
    2.  The second was a stripped down rewrite based on lessons learnt from version one, but that only supports current S/W versions; this version is maintained on this `main` branch.
    3.  The third implements the changes discussed and scoped in #12.  This includes the switch to `mariadb-server` and the Debian packages which use `glibc` rather than `MUSL`, and use ofUnix sockets rather than Docket networking for inter-container networking.
*  The Dockerhub official] Debian (`bullseye-slim`) image is used as a basis for all containers, with a single `Dockerfile` used to install all of the relevant Debian packages needed to support the services, including those supporting the IC LAMP stach: `apache2`(`php-cli` and `php-fpm` (together with the PHP modules needed to run the IC Suite), together with the  modules needed to run the website), `certbot`, `redis-server` and `sshd`.
*  All running services follow the standard Docker practice of each container presenting a single service that runs as a foreground process (though some execute load-balancing child processes), with the Docker runtime using `tini` as the initiator.
*  I have adopted a mixed logging strategy:
*  High volume informational logs (such as the Apache2 access logs) are written to a persistent shared `/var/log` volume (as these are only occasionally mined for hacking forensics), and these are trimmed using standard Linux log rotation. Other services use the Docker logging system.
*   The `sshd` service is mounted onto port 2222 and offers a single user with `/backups` as the home directory. This user has read access to the backups hierarchy; this provides authorised users (who are not sysAmins) public-key read-only access for off-site duplication).
*  Timed events (such as backup and log rotation) are orchestrated by a small custom Python app in the `scheduling` service.

## Customising the Service Context

*  Persistent data that is private to service is mapped through shared Docker volumes.
*  Each service is configured through its own `service` subfolder.  This contains two sub-folders:
    *   **`bin`** contains any bash scripts that will be used to configure the service.  This folder is mapped read-only to `/usr/local/sbin` in the running service.
    *   **`conf`** contains any files that will be used to configure the service.  As small modifications are done by the startup script, this is typically only used when a config file completely replaces the standard default.  If this folder exists, it is mapped read-only to `/usr/local/conf` in the running service.

Note that the hidden `.env`, and `.secret` files are not under change control and are excluded from the github repository, but allow installation-specific secrets to be passed to running stack. `env.default-template` documents how to set these up.

## Backup

Nightly backup is also managed as a housekeeping function, and backups are written to the backups volume.  The `sshd` service implements ssh access to a restricted account with its home folder mapped to the backups volume.  This enables authorised users to `rsync` the backups to a local offsite copy.

## See Also

*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributors) comments on open issues.
