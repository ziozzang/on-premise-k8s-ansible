#!/bin/bash

# Check Docker permission
docker ps > /dev/null 2> /dev/null

if [ "$?" -ne "0" ]; then
  echo "Docker(Docker in Docker) cannot run."
  exit 1
fi

TEMP_FILES=$(mktemp /tmp/output.XXXXXXXXXX)

cd /images
ls > ${TEMP_FILES}
while read p; do
  gunzip -c ${p} | docker load
done < ${TEMP_FILES}

