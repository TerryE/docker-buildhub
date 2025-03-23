
# Invision Community Docker Stack for the Buildhub Forum

## Table of Contents

* [Background](#background)
* [Design Decisions](#design-decisions)
* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Configuration](#configuration)
* [Service Descriptions](#service-descriptions)
* [Backup and Restore](#backup-and-restore)
* [Maintenance](#maintenance)
* [Troubleshooting](#troubleshooting)
* [Security Considerations](#security-considerations)
* [Contributing](#contributing)
* [License](#license)

## Background

This project provides a Docker Compose stack for deploying an Invision Community (IC) forum on a self-managed virtual private server (VPS).

This stack was originally developed for a special interest forum that uses Invision Community (IC) application as its engine. This was subsequently moved to Docker to simplify host migration, ensure configuration control, and to allow for easier maintenance. This also provides a level of sysAdmin independence because of the clear, reproducible server configuration. This Docker stack is currently hosted on a self-managed 6-core VPS.  SysAdmin of Docker and the host OS is done at the command-line using remote access via SSH with public key authentication. All other IC services are managed from within the IC Admin panel, which is accessible through standard HTTPS.

## Design Decisions

* **Docker Images:** The LAMP stack uses the same image for all containers.  This is based on the official Debian `bullseye-slim` image with the other packages added to to support IC, in order to provide a lightweight and stable base.
* **Service Isolation:** Each container runs a single service, adhering to Docker best practices for maintainability.
* **Mixed Logging:** High-volume logs (e.g., Apache access logs) are stored in a persistent volume with log rotation, with the other services use Docker logging.
* **Secure SSH Access:** SSH access is provided to a dedicated user / port with read-only access to the `/backups` volume, to enable secure off-site backup retrieval.
* **Unix sockets:** Inter-container networking is done via Unix sockets for improved performance and security.
* **MariaDB and Glibc:** `mariadb-server` is used for the Database and the main advantage of the move to Debian from Alpine is that PHP typically bechmarks about 15% faster using `glibc` compared to `MUSL`.
* **Main File Trees are bound to the VPS Host File System**.  The containers bind the to the host`/forum` and `/backups` directories where needed, and likewise each service binds to a `conf` and `bin` folder to `/usr/local` mount points and these are use to start and configure each service in a simple and consistent manner.
* **Custom Python Scheduling:** A small custom Python script within the `scheduling` service uses the Docker API to manage timed events such as backups and log rotation across the other services.

## Prerequisites

* A hosting server preferably running Debian or Ubuntu. The production server is a current 6-core Xeon VPS in a data-centre and running at a typical utilisation for 10-15% though this occasionally peaks at 40% or so.  A test instance will run happily on a 1-core VPS running on a Proxmox host.
* Docker and Docker Compose installed.
* Git installed.

The forum is managed and maintained through a common account `forum`, which is a member of the `docker` group, but otherwise non-root,  Admins log in over SSH to their own accounts which they also use for any other occasional sudo action, but the practice is to use the alias `forum='sudo -u forum -i'` to work on the forum.  The`.bash_rc` file for this sets the Docker Environmen  t and some common aliases (such as `dc` for `docker compose`), so executing the `forum` command both switches to the forum user and sets this context.

## Installation

1.  Clone the repository using `git clone`
2.  Create `.env` and `.secret` files based on `env.default-template`. These files contain sensitive information and should be securely managed outside of git.
3.  The project image can be build with `dc build | tee /tmp/forum.log` and that stack started with `dcu`
4.  About once a month an admin does a routine stack update by doing `dc build --no-cache | tee /tmp/forum.log; dcd; dcu; docker prune -f` to do a complete stack update.
The forum is only down for seconds so we just do this out of hours without a scheduled downtime.  Since the forum long predates the use of Docker, we've never tested out doing a complete green IC install, but setting new test instance simply involves unpacking the latest backups into `/forum/ and executing bash in the `mysql` and using mysql client to create the forum DB, user, do the grants and source the last SQL backup into the new DB.

## Configuration

* **Environment Variables:** Configure environment variables in the `.env` and `.secret` files.
* **Service Configuration:** The customi service configurations in the `service/<service>/conf` directories. For example, Apache configurations can be modified in `service/apache/conf/`.
* **Custom Scripts:** Add custom scripts to the `service/<service>/bin` directories. These scripts are mounted read-only to `/usr/local/sbin` in the running service.

## Service Descriptions

* **Apache2:** Web server for the Invision Community Suite. The configuration is in `service/apache2/conf/`. The `Certbot` tool for obtaining and renewing SSL certificates, ensuring secure HTTPS connections is run as a scheduled action in this container.
* **PHP:** The PHP-FPM server for executing PHP scripts
* **Mysql** The MariaDB server for storing forum data. The configuration is in `service/mysql/conf/`.
* **Redis:** In-memory data store for caching, improving performance.
* .  This runs as a scheduled callback in the `Apache2` container.
* **SSHD:** Secure Shell server for backup access, restricted to a dedicated user. Configuration is managed within the docker compose file.
* **Scheduling:** Python application for timed events, such as backups and log rotation. Configuration is managed in `service/scheduling/`.

## Backup and Restore

* **Backup Process:** Nightly backups are performed by the `scheduling` service and stored in the `/backups` volume.
* **Backup Retrieval:** Authorised users can retrieve backups via SSH using the dedicated user account.
* **Restore Process:** To restore, copy the backup files to the appropriate service data volume and restart the services. Example restoring database:
    1. Stop the mariadb container.
    2. copy the backup to the mariadb data directory.
    3. start the mariadb container.

## Maintenance

* **Updating Services:** Use `dc build` to pull and update images, and `dcd` to restart services.
* **Log Management:** High-volume logs are managed by standard Linux log rotation. Other logs can be managed using Docker logging drivers.
* **Security Updates:** Regularly update the base Debian image and application dependencies.

## Troubleshooting

* **Service Startup Issues:** Check Docker logs using `dl [container name]`.
* **Database Connection Errors:** Verify database credentials and network connectivity.
* **SSL Certificate Issues:** Check Certbot logs and ensure domain name resolution.
* **SSH Connection Problems:** Verify SSH configuration and public key authentication.

## Security Considerations

* **Environment Variables:** Securely manage `.env` and `.secret` files, restricting access.
* **SSH Access:** Use public key authentication and restrict SSH access to authorised users.
* **Firewall:** Configure a firewall to allow only necessary ports (2222, 80, 443, 8080, 4443).
* **Regular Updates:** Keep the base Debian image and application dependencies up to date.
* **Docker Security:** Follow Docker security best practices, such as using non-root users in containers.

## Contributing

Contributions are welcome. Please submit pull requests with clear descriptions of the changes.

## License

This project is free to use

## See Also

*  [Current Issues](//github.com/TerryE/docker-buildhub/issues) for my (and other contributors) comments on open issues.
