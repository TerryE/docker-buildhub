## Architecture Overview

In early Compose projects I found easy to do clone-tweak-and-repeat across multiple containers, but this leads to poor maintainability.  In order to keep the code base compact, I share code and confuration setup across all containers where practical. At the same time I also try to follow the Docker best practices for maintainability: that each container should be scoped to and run a single service.  Each container therefore needs its own start-up and ability to configure its 'personality'.  Most services also have time-related periodic housekeeping that needs to be run within the container context: logfiles to be rotated; data to be backed up; heatbeat task initiation.  Hence, a mechanism is needed to schedule such activitirs and to run them in the relevant container.

The architecture arises from these drivers as refined over a couple of VPS migrations:

*  All containers shared the some Docker image based on the DockerHub standard Debian `bullseye-slim` image with all Debian packages added to support IC and the LAMP services.
*  All containers share a common set of utility scripts in a shared `sbin` directory that is mounted in all containers
*  Each container has its own `bin` and (optionally) `conf` mountpoints.
*  All containers also share a `run` mountpoint to faciliate inter-containers unix socket communication

So each service declaration in [docker-compose.yaml](./docker-compose.yaml) encludes the following standard volume mountpoints:

```yaml
  volumes:
    - ./target_sbin:/usr/local/sbin:ro
    - ./service/<service>/bin:/usr/local/bin:ro
    - ./service/<service>/conf:/usr/local/conf:ro
    - ./data/run:/run
```
The [Dockerfile](./Dockerfile) also includes
```Dockerfile
WORKDIR /usr/local
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/sbin/supervisor.py"]
```
so by default each continer uses `tini` to start [supervisor.py](./target-sbin/supervisor.py). If you review this code, you will see that this is a small multi-threaded supervisor that:
*  Starts two child processes:
   *  The shared [entrypoint.sh](./target-sbin/entrypoint.sh) that in turn sources [docker-entry-setup.sh](./service/mysql/bin/docker-entry-setup.sh). (This is the `mysql` example.) It mainly sets the 6 or so ENV variables that the entrypoint script needs to chain to the executable used to implement this service.
   *  The shared [listener.sh](./target-sbin/listener.sh) that in turn sources [docker-callbacks.sh](./service/mysql/bin/docker-callbacks.sh). (This is again the `mysql` example); in this case it defines two functions `CB_rotate_logs` and `CB_nightly_backup` that the listener script needs to execute `rotate-logs` and `nightly-backup` housekeeping tasks.)
*  Establishes a listener on `<service>-request.sock` and passes these messages to the `stdin` for its `listener.sh` child process.
*  Handles any signal propagation from its PID 1 parent `tini` process to its children.
*  Handles any child errors and orchestrates and signal propagation needed.

One service doesn't follow this pattern: The **scheduler**'s `service` declaration includes a `command: ['bin/scheduler.py']` directive, so here `tini` starts [scheduler.py](./service/scheduler/bin/scheduler.py), that reads a crontab-like [schedule.cron](./service/scheduler/conf/schedule.cron) file and outputs the necessary houskeeping requests according to this schedule. For example, the entry:
```
#min hour dom mon dow [user] service action
  5    4   *   *   *  forum  mysql   nightly-backup
```
issues the houskeeping request `forum nightly-backup` on `mysql-request.sock` at 04:05 every day, which read by the MySQL service `supervisor.sh` and passed to its `listener.sh` which then executes its `CB_nightly_backup` function at 04:05.
