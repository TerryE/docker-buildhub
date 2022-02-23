## Background

The scope of this project is a special interest forum that uses [Invision Community (IC)](https://invisioommunity.com/) as its forum engine; this is served on a bare / self-managed VP that I've rehosted a few times over the years, mainly because the storage requirement have grown and we need to use a supported LTS stack.  The current 6-core VPS with SSD storage costs less than the 2-core + HDD VPS that we initially commission 6 years ago, and is a lot less than that of using a managed IC service.

I have provided pro-bono SysAdmin and developer contributions to various not-for-profit sites and open-source projects, but I am now retired and am winding down these activities now that. SysAdmin for this forum remains, and so future SysAdmin continuity is a concern.  As I have used Docker for other projects, I have decided to move to using a Docker stack for the new Ubuntu 20.04-LTS server and to simplify migration. This server has been kept as a bare Docker, with the only host open port SSH access by public key, and the only extra  installed packages being `docker-compose`, `docker.io`, `etckeeper`, `git`, `iotop`, `iostat`, `nmap`, `screen`, `tree`, `unzip`, `vim`, `whois`, `xz-tools` and `zip`.

I have a single docker compose project (as per this GitHub repo) that can spin up separate LAMP stacks for our production and test subdomains:
-  *forum*.  Open ports 80 (for port forwarding), 443
-  *test*.   Open ports 8080 (for port forwarding), 4443

Using disjoint ports means that we only need one external IP address and no reverse proxy.

A major advantage of Docker is that the setup and configuration is encapsulated in a single directory hierarchy, comprising a few dozen files, a total of ~1K lines of script, config and comments, and controlled through Git.

So long as the hosting server has `git` and `docker`  installed, then anyone with access to the forum backup files, and copies of the `.env` and `.secret` contents could install a local copy of the forum with a couple of commands.  This makes it a lot easier for another SysAdmin so understand how our forum's server is configured.

## Design decisions

*  This configuration is openly accessible via GitHub. I've followed the usual practice of excluding the few dozen lines of `.env` and `.secret` content, which needs to be shared privately.
*  Our images are based on Docker's own official Mysql and Alpine images.
*  All running containers follow the common Docker practice of presenting a single service which runs as a foreground process (though some execute load-balancing child processes), with the Docker runtime doing the daemonisation.
*  I have extended the standard `alpine:3.15` by aligning the `PID` and `GID` allocations for `www-data` to those of the host to simplify UID based access across volumes, and by installing the relevant Alpine packages to support the following:
   *  `php-cli` and `php-fpm` (together with the PHP modules needed to run the IC Suite)
   *  `apache2`(together with the apache2 modules needed to run the website)
   *  `redis-server`
   *  `crond`
*  The `docker_compose.yaml` spins up four containers based on this image, one for each of the `apache2`, `hk`, `php` and `redis` services.  Where needed the relevant `conf` and `bin` sub-folders are mapped into `/usr/local/${HOSTNAME}/`  `bin` and `conf` directories, and a couple of hook scripts personalise the container to the `HOSTNAME`.  The fifth `mysql` container uses the offical `mysql` image because this has a complicated startup that handles recovery for unscheduled shutdown, DB upgrades, etc.. See the forum sub-folder readme for more details.
*  I have adopted a mixed logging strategy, rather than pure Docker: I have left genuine error exceptions to be reported by the Docker logging system, but higher volume logging such as the Apache2 access logs are sent to a persistent shared `/var/log` volume (as these are only occasionally mined for hacking forensics).
*  A dedicated housekeeping `hk` container does daily forum backup, logrotation and other cron-based housekeeping. See the files `docker-callback-reader.service` and `docker-callback-reader` in the `extensions` tree for how this is implemented.
*  Most persistent data is mapped through shared Docker volumes. Indiviual containers also map and `conf` and `bin` subfolders as `read-only` volumes to customise the services. I do this on an either-or approach: where the `conf` files only need a few tweaks then a `bin` hook script does `sed` edits to change the package defaults. The `apache2` is the other mode where I have swapped out the main `conf` files.
*  The Docker application presents a minimal security surface.  Hence intra-container communication is carried out over a private `ipam` network and only the HTTP and HTTPS ports exposed to the host.

##  Still TODO

(Most of these are just script migration from the exist prod service )
* Move php-fpm access log to /var/logs
* Implement logrotation
* Implement the nightly backup
* Using environment context so a single forum tree can be used to build both test and prod instances.

## See Also

*  [Migration Notes](//github.com/TerryE/docker-buildhub/wiki/Migration-Notes) on process for migrating from old-server
*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributers) comments on open issues.
