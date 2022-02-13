## Background

The scope of this project is a special interest forum that uses [Invision Community (IC)](https://invisioncommunity.com/) as its forum engine; this is served on a bare / self-managed VPS, and we've rehosted a few times over the years, mainly because the storage requirement have grown and we need to use a supported LTS stack.  The current 6-core VPS with SSD storage now costs less that the 2-core + HDD VPS that we initially commission 6 years ago, and also and many factors less than using a managed IC service.

My career was in IT and I consider myself a competent SysAdmin and developer.  I have administered forums, wikis and WordPress sites pro-bono for various communities over the years, but am now retired, so future SysAdmin continuity on this forum is a concern for me.

As I have used Docker for other projects, I have decided to move to using a Docker stack foe the migration to the new server; this has been kept as a bare Docker host based on  Ubuntu  20.04-LTS.  The only open service on the host is keyed access SSH wth the only extra added packages being `docker-compose`, `docker.io`, `etckeeper`, `git`, `iotop`, `iostat`, `nmap`, `screen`, `tree`, `unzip`, `vim`, `whois`, `xz-tools` and `zip`.

I have one docker compose project (as per this GitHub repo) that can spin up separate LAMP stacks for our production and test subdomains:
-  *forum*.  Open ports 80 (for port forwarding), 443
-  *test*.   Open ports 8080 (for port forwarding), 4443

Using disjoint ports means that we only need one external IP address and no reverse proxy.

A major advantage of Docker is that the setup and configuration is encapsulated in a single directory hierarchy, comprising a few dozen files, a total of less than 1,000 lines of script, config and comments, and controlled through Git.

So long as the hosting server has `git` and `docker`  installed, then anyone with access to the forum backup files, and copies of the `.env` and `.secret` contents could install a local copy of the forum with a couple of commands.  This makes it a lot easier for another SysAdmin so understand how our forum's server is configured.

## Design decisions

*  This configuration is openly accessible via GitHub. I've followed the usual practice of excluding the few dozen lines of `.env` and `.secret` content, which needs to be shared privately.
*  Our images are based on Docker's own repository of official images. These official images typically include variants based on the Debian and Alpine distros. Using a Debian base the major advantage that the host used Ubuntu 20.04 and hence shares the same UID and GID standards which makes file ownership and access for file volumes shared between the host and the containera is easier (e.g. `www-data` is the same on both).
*  Some of the containers require extra components to be installed.  For example, the Forum software needs extra PHP extensions to be added via PECL building, so these longer duration build steps have been split out.  For example we build a `php:8.0-extra` based on the Docker official `php:8.0-fpm-bullseye` and the Docker Compose stack uses `php:8.0-extra`. This means that any config changed can be added to the running system by a `build`  + `up` that takes seconds rather than minutes.
*  All running containers follow the common Docker practice of presenting a single service which runs as a foreground process (though some execute load-balancing child processes), with the Docker runtime doing the daemonisation.
*  I have adopted a mixed logging strategy, rather than pure Docker: I have left genuine error exceptions to be reported by the Docker loggging system, but higher volume logging such as the Apache2 access logs are sent to a persistent shared `/var/log` volume (as these are only occasionally mined for hacking forensics).
*  A separate dedicated housekeeping instance does daily forum backup, logrotation and the forum cron housekeeping task. See the files `docker-callback-reader.service` and `docker-callback-reader` in the `extensions` tree for how this is implemented.
*  Most persistent data is mapped through shared Docker volumes, though a couple of volumes are mapped to the hosting filesystem.
*  The Docker application presents a minimal security surface.  Hence intra-container communication is carried out over a private `ipam` network and only the HTTP and HTTPS ports exposed to the host.

##  Still TODO

(Most of these are just script migration from the exist prod service )
* Move php-fpm access log to /var/logs
* Implement logrotation
* Implement the nighly backup
* Using environment context so a single forum tree can be used to build both test and prod instances.

## See Also

*  [Migration Notes](//github.com/TerryE/docker-buildhub/wiki/Migration-Notes) on process for migrating from old-server
*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributers) comments on open issues.
