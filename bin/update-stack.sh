#! /bin/bash
cd $(dirname $0)
#
# Loop around images and pulling each in turn.  If the ID has changed then set
# BUILD=YES to flag that a stack rebuild is required.
#
IMAGES='mysql:8.0-debian alpine:3.19'
declare BUILD id
for i in $IMAGES; do
  id=$(docker inspect -f {{.ID}} $i)
  docker pull $i
  [ "$(docker inspect -f {{.ID}} $i)" == "$id" ] || BUILD=YES
done

[ -z "$BUILD" ] && exit  #exit if nothing has been pulled

#
# Do a forced rebuild of the stack and prune any dangling images
#
docker-compose up -d --force-recreate --build
docker rmi $(docker images -f "dangling=true" -q)
