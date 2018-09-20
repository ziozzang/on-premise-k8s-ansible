#!/bin/bash
# This script is push binary only
DOCKER_TAGS=${DOCKER_TAGS:-"kubebins"}

LOG_FILE=$(mktemp /tmp/output.XXXXXXXXXX)
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Reset Kubernetes
kubeadm reset -f
rm -fr $HOME/.kube logs
docker images | awk '{print $3}' | xargs docker rmi -f

# Docker image pull or load from files. anything?
docker pull ${DOCKER_TAGS}
#docker load < /tmp/kubebins.tar

# Copy & Dump files
docker run \
  --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /:/host \
  --privileged \
  ${DOCKER_TAGS}

# Set IP based Hostname
IP=`hostname -i | awk '{print $1}' | tr '\.' -`
hostname "host-${IP}"

if [ `echo "${PATH}" | grep "/opt/bin" | wc -l` -eq "0" ]; then
  export PATH=$PATH:/opt/bin
fi

if [ `grep 'PATH' ~/.bashrc | grep '/opt/bin' | wc -l` -eq "0" ]; then
  echo 'export PATH=$PATH:/opt/bin' >> ~/.bashrc
fi

# Restart
swapoff -a
