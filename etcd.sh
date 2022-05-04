#!/bin/bash
#set -xeuo pipefail

BACKUP_PATH=~/backup
TODAY_DATE=$(date '+%Y-%m-%d-%H-%M')
RANCHER_COPY_NAME=rancher-data-${TODAY_DATE}
NAME=$(docker ps -a -f status=running --format "{{.Image}} {{.Names}}" | grep -i "rancher/rancher:v" | cut -d' ' -f2)
IP=$(docker images -a --format "{{.Repository}}" | grep -i "rancher/rancher/rancher-"  | cut -d "/" -f1)
tag=$(docker ps -a -f status=running --format "{{.Image}} " | grep -i "rancher/rancher:v" | cut -d ':' -f2)
mkdir -p ${BACKUP_PATH}
docker stop $NAME
docker create --volumes-from $NAME --name ${RANCHER_COPY_NAME} ${IP}/rancher/rancher/rancher:${tag}
docker run  --volumes-from ${RANCHER_COPY_NAME} -v ${BACKUP_PATH}:/backup:z busybox tar pzcvf /backup/rancher-data-backup-${tag}-`date '+%Y-%m-%d-%H-%M'`.tar.gz /var/lib/rancher
docker start $NAME

