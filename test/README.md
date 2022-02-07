The test directory contains the scripts and configration files to build and start the docker images and containers needed to run the test forum.

These containers are ultimately based on the standard Docker Repository images:

*  `debian:bullseye`, `httpd:2.4-bullseye`,
*  `mysql:5.7`, `mysql:8.0`, `
*  `php:7.2-fpm-buster`, `php:8.0-fpm-bullseye`

Note that the early versions of mysql and php are use only for migration of the forum from the legacy version 4.4 to the current 4.6.10.  I have also extended these images (less the mysql ones by adding some useful apt packages to support debugging, etc.  The following images are built in the sister externsion folder:

*  `debian:bullseye-extra`, `httpd:2.4-extra`, `php:7.2-extra`, `php:8.0-extra`

The four `<container>-dockerfile` files are used to build the images used in the running containers by adding `environment`, `bin` commands and `etc` configuration data

*  `hk:latest`, `httpd:latest`, `mysql:latest`, `php:latest`

Note that the hidden `.env`, and `.secret` file are not part of the github repository

The overall application build is commented in the `docker-compose.yaml` file

Enjoy!

```
test
├── docker-compose.yaml               The Docker Compose file used by build-all
├── .env                              Environment declarations use in the LAMP stack
├── hk-dockerfile                     )
├── httpd-dockerfile                  ) Docker files for apache, mysql and php container
├── mysql-dockerfile                  )
├── php-dockerfile                    )
├── bin
│   ├── build-all                     Bash script to pull every together
│   ├── callback-reader               Daemonised bash script to listen to requests from hk
│   └── hk
│       ├── hk-startup
│       ├── ipb_task_maintenance
│       └── logrotate
├── etc                               the etc config file copied into the containers
│   ├── httpd
│   │   ├── extra
│   │   │   ├── HTTPtoHTTPS.conf
│   │   │   └── test-ssl.conf
│   │   └── httpd.conf
│   ├── hk
│   │   └── crontab
│   ├── mysql
│   │   └── conf.d
│   │       ├── docker.cnf
│   │       └── mysql.cnf
│   └── php
│       ├── php
│       │   └── php.ini
│       └── php-fpm.d
│           └── www.conf
└── .secrets                           The test.buildhub.org.uk certs used by apache
    ├── fullchain.pem
    └── privkey.pem
```