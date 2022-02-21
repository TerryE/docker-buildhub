The test directory contains the scripts and configration files to build and start the docker images and containers needed to run the test forum.

These containers are ultimately based on the standard Docker Repository images:

-  `alpine:3.15`,
-  `mysql:5.7`or `mysql:8.0`, `

The mysql startup is highly scripted, hence I am sticking with the standard MySQL image which does all this magic out of the can.

The other four containers all use the same the extended alpine image to offer the `apache2`, `hk` (cron based housekeeping) `php` and `redis`.

The `docker-entrypoint.sh` script in `/usr/local/bin` handles the service specific startup based on the service name.dispatch of time-based callback requests from the `hk` services.

The configuration settings for each service are handled by one of two mechanisms:

-  In the case where only minor tweaks are needed to package installed /etc files then a small `/usr/local/<service>/bin/startup-hook` typically does one or more `sed` commands to fixup the relevant 'conf' files (e.g. `php` and `redis`).
-  In other case a complete conf file is volume bound to wildcard `conf.d` subfolder or replacing the config hierarchy in its entirity.

Also `service_<task>` scripts can be added to `/usr/local/<service>/bin/` to handle service specific tasks (e.g. the PHP `task.php` executed every minute to service the IP Suite background queues.)

Note that the hidden `.env`, and `.secret` files are not part of the github repository

The overall application build is commented in the `docker-compose.yaml` file

Enjoy!
