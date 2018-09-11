#!/bin/bash
# This is sample script to build
CNI_VERSION="v0.7.1"  ./get_latest.sh
docker save kubebins > kubebins.tar
scp kubebins.tar root@1.2.3.4:/tmp/
rm -f kubebins.tar
