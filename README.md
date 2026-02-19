# Invision Community Docker Stack for the Buildhub Forum

## Background

This project provides the Docker Compose stack for the Buildhub Forum to provide a LAMP stack running Invision Community Suite (ICS) on a self-managed virtual private server (VPS).  This stack was originally developed for VPS hosted LAMP stack, but thid was subsequently migrated during an VPS upgrade in early 2022 to Docker Compsose in order to simplify host migration, to ensure configuration control, and to allow for easier maintenance.   

This forum is currently hosted on a dedicated self-managed 6-core VPS.  System administration of Docker and the host OS is done at the command-line using remote access via SSH with public key authentication. All other IC services are managed from within the IC Admin panel, which is accessible through standard HTTPS.

## Design Decisions for the Docker Stack

* **Docker Images:** The LAMP stack uses the same image for *all* containers.  This is based on the official Debian `trixie-slim` image with the other packages added as needed to support stack services.
* **Service Isolation:** Each container runs a single service, adhering to Docker best practices for maintainability.
* **Mixed Logging:** High-volume logs (e.g. Apache access logs) are stored in a persistent volume with log rotation, with low log volume services using Docker logging.
* **Unix sockets:** Inter-container networking is done via Unix sockets for improved performance and security.
* **MariaDB:**`mariadb-server` is used for the Database.
* **Glibc RTL:** The main reason for the move from Alpine to Debian is that PHP typically bechmarks about 15% faster using `glibc` compared to `MUSL`.
* **The Main Forum File Trees are bound to the VPS Host File System**.  The containers bind   to the host`/forum` and `/backups` directories where needed, and likewise each service binds to a  `bin` and `conf` sub-folder to `/usr/local` mount points and these are use to start and configure each service in a simple and consistent manner.
* **Custom Python Service Manager**. A small custom Python script within the all services to manage clean service startup and shutdown.  It also spawns a subprocess to act as a listener for scheduled actions to be run in the containers
* **Custom Python Scheduling:** A small custom Python script within the `scheduling` service passes timed events such as backups and log rotation to the other services using their listener sockets.
* **Configured Secrity**. The server uses a tailored `ufw` with the stack using `fail2ban`, Geo-blocking and ip table filtering to protect service integrity.
* **DR Backup Sets On Cloud Storage:** Daily Backups are moved off VPS to cloud storage.  Other admins have access accounts to this backup repository.

## Service Overview

* **Apache2:** Web server hosts the ICS application over HTTPS.  `Certbot` is used to obtaining and renewing the SSL certificates.
* **PHP:** The PHP-FPM servive executes PHP scripts
* **Mysql:** The MariaDB server for storing forum data. 
* **Redis:** In-memory data store for caching, improving performance.
* **Fail2ban:** This is used to scan the Apache log files for signs of brute-force attacks or suspicious activity—such as too many failed login attempts it dynamically bans the offending IPs using firewall rules in iptables shared with `Apache2`.
* **Scheduling:** Python application for timed events, such as backups and log rotation. Configuration is managed in `service/scheduling/`.

The Service Archtecture is described in a separate document: [Service Architecture](./Service_Architecture.md).

## Prerequisites

* A hosting server preferably running Debian or Ubuntu. The production server is a current 6-core Xeon VPS in a data-centre and running at a typical utilisation for 10-15% though this occasionally peaks at 40% or so.  A test instance will run happily on a 1-core VPS running on a Proxmox host.
* Docker and Docker Compose installed.
* Git installed.

Note that the forum is managed and maintained through a common account `forum`, which is a member of the `docker` group, but otherwise non-root,  Admins log in over SSH to their own accounts, which they also use for any other occasional sudo action. The practice is to use the alias `forum='sudo -u forum -i'` to work on the forum.  The`.bash_rc` file for this sets the Docker Environment and some common aliases (such as `dc` for `docker compose`), so executing the `forum` command both switches to the forum user and sets this context.

## Configuration

* **Environment Variables:** Configure environment variables in the private `.env` and `.secret` files.
* **Service Configuration:** The customi service configurations in the `service/<service>/conf` directories. For example, Apache configurations can be modified in `service/apache/conf/`.
* **Custom Scripts:** Add custom scripts to the `service/<service>/bin` directories. These scripts are mounted read-only to `/usr/local/sbin` in the running service.

## Installation

1.  Clone the repository using `git clone`
2.  Create `.env` and `.secret` files based on `env.default-template`. These files contain sensitive information and should be securely managed outside of git.
3.  The project image can be build with `dc build | tee /tmp/forum.log` and that stack started with `dcu`
4.  About once a month an admin does a routine stack update by doing `dc build --no-cache | tee /tmp/forum.log; dcd; dcu; docker prune -f` to do a complete stack update.
The forum is only down for seconds so we just do this out of hours without a scheduled downtime.  Since the forum long predates the use of Docker, we've never tested out doing a complete green IC install, but setting new test instance simply involves unpacking the latest backups into `/forum/ and executing bash in the `mysql` and using mysql client to create the forum DB, user, do the grants and source the last SQL backup into the new DB.

## Backup and Restore

Nightly backups are performed by the `scheduling` service and stored in the `/backups` volume; a host cronjob subsequently uploads the cloud service.  Authorised users can retrieve backups from the cloud service; these can be restored into a fresh installation.

## Maintenance

* **Updating Services:** Use `dc build` to pull and update images, and `dcd` to restart services.
* **Log Management:** High-volume logs are managed by standard Linux log rotation. Other logs can be managed using Docker logging drivers.
* **Security Updates:** Regularly update the base Debian image and application dependencies.

## Security Considerations

* **Environment Variables:** Securely manage `.env` and `.secret` files, restricting access.  Everything else is under change contol in this Github repository.
* **Firewall:** `ufw` allows incoming requests only the necessary ports (80, 443, 8080, 4443), plus SSH locked down to speific Admin IPs. Geo-blocking + `Fail2ban` + Docker `iptables` are used within the Docker stack to block DoS and other suspicious activities 
* **Regular Updates:** Keep the base Debian image and application dependencies up to date.
* **Docker Security:** Follow Docker security best practices, such as using non-root users in containers.

## Contributing

Contributions are welcome. Please submit pull requests with clear descriptions of the changes.

## License

This project is free to use.

## See Also

*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributors) comments on open issues.
