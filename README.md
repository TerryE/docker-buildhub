## Background

I an a competent SysAdmin and developer, and I have administered pro-bono various community forums, MediaWiki sites and WordPress sites over the years.  The scope of this project is a special interest forum that uses [Invision Community (IC)](https://invisioncommunity.com/) as its forum engine; this is served on a bare / self-managed VPS, and we've rehosted a few times over the years, mainly because the storage requirement have grown and and we need to use a supported LTS stack.  The current 6-core VPS with SSD storage now costs less that the 2-core + HDD VPS that we initially commission 6 years ago, and also and many factors less than using a managed IC service.

However, I am now retired and future SysAdmin continuity is concern for me. As I have used Docker for other projects, it seemed a good idea to move to using a Docker stack on what is essential a minimal hosting service provider Ubuntu LTS instance.  The only open service on the host is SSH (certificated only), and the only extra added packages that I've added beyond the template Ubuntu 20.04-LTS configuration are:
```bash
apt-get install -y docker-compose docker.io etckeeper git iotop iostat \
                   nmap screen tree unzip vim whois xz-tools zip
```
I have one docker compose project (as per this GitHub repo) that can spin up separate LAMP stacks for our production and test subdomains:
-  *forum*.  Open ports 80 (for port forwarding), 443
-  *test*.   Open ports 8080 (for port forwarding), 4443

Using disjoint ports means that we only need one external IP address and no reverse proxy.

A major advantage of Docker is that the setup and configuration is encapsulated in a single single directory hierarchy, comprising a dozen or so files (a total of < 1K lines including a lot of comments, and change control tracked through git).  So long as the hosting server has `git` and `docker`  installed, then anyone with access to the forum backup files, and copies of the `.env` and `.secret` contents could install a local copy of the forum with a couple of commands.  This makes it a lot easier for another SysAdmin so understand how our forum's server is configured.

## Design decisions

*  This configuration is openly accessible via GitHub. I've followed the usual practice of excluding the few dozen lines of `.env` and `.secret` content, which needs to be shared privately.
*  Our images are based on Docker's own repository of official images. These official images typically include variants based on the Debian and Alpine distros. (Alpine is an absolute bare-bones distro optimised for VM and container use; images based on it are typically 40 Mb smaller than Debian ones, although the memory and other resources used by the running containers is almost the same).  Debian Bullseye has the major advantage that the hosting Ubuntu 20.04 server is itself based on Bullseye, hence these share the same UID and GID standards which makes file ownership and access for file volumes shared between Ubuntu and the container is a lot easier (e.g. `www-data` is the same on both).
*  Some of the containers require extra components to be installed.  For example, the Forum software needs extra PHP extensions to be added via PECL building. I have therefore split out these longer duration build steps so for example we build a `php:8.0-extra` based on the Docker official `php:8.0-fpm-bullseye` and the Docker Compose uses `php:8.0-extra`. This meand that any config changed can be added to the running system by a `build`  + `up` that takes seconds rather than minutes.
*  All running containers follow the common Docker practice of presenting a single service which runs as a foreground process (PID=1) (though some execute load-balancing child processes), with the Docker runtime doing the daemonisation.
*  I have adopted a mixed logging strategy, where I've left genuine error exceptions to be reported by the docker log mechanism but higher volume logging such as the Apache2 access logs are sent to a persistent shared `/var/log` volume, as these are only occasionally mined for hacking forensics.
*  A separate dedicated housekeeping instance does daily forum backup, logrotation and the forum cron housekeeping task. See the files `docker-callback-reader.service` and `docker-callback-reader` in the `extensions` tree for how this is implemented.
*  Most persistent data is mapped through shared Docker volumes, though a couple of volumes are mapped to the hosting filesystem.
*  The Docker application presents a minimal security surface.  Hence intra-container communication is carried out over a private `ipam` network and only the HTTP and HTTPS ports exposed to the host.

##  Still TODO

(Most of these are just script migration from the exist prod service )
* Move php-fpm access log to /var/logs
* Implement logrotation
* Implement the nighly backup
* Using environment contect so a single forum tree can be used to build both test and prod instances.

## See Also

*  [Migration Notes](//github.com/TerryE/docker-buildhub/wiki/Migration-Notes) on process for migrating from old-server
*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributers) comments on open issues.
