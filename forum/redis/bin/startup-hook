#! /bin/bash
#
# redis.conf is in /etc.  Change the following defaults.
#
sed -i '/databases /s!.*!databases 4!
        /^\(# \)\?maxmemory /s!.*!maxmemory 8mb!
        /^\(# \)\?maxmemory-policy /s!.*!maxmemory-policy allkeys-lru!' /etc/redis.conf
