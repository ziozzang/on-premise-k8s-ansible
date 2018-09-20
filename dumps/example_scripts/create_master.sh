#!/bin/bash
# This script is sample master build
DOCKER_TAGS=${DOCKER_TAGS:-"kubebins"}
POD_NETWORK_CIDR=${POD_NETWORK_CIDR:-"100.64.0.0/10"}


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
VERS=`cat /opt/config.yml | awk '{print $2}'`
kubeadm init \
  --pod-network-cidr="${POD_NETWORK_CIDR}" \
  --kubernetes-version="${VERS}" \
  | tee ${LOG_FILE}

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

cd /opt/pkg

PKG_FILE=$(mktemp /tmp/output.XXXXXXXXXX)
ls > "${PKG_FILE}"
while read p; do
  kubectl create -f ${p}
done < "${PKG_FILE}"
rm -f "${PKG_FILE}"

# Create CNI(Network)
#kubectl apply -f /opt/pkg_dl/rbac.yaml
#kubectl apply -f /opt/pkg_dl/calico.yaml


cd "${CURRENT_DIR}"
LOGS=`grep "kubeadm join" ${LOG_FILE}`
echo "RUN>> ${LOGS}"
echo "${LOGS}" > join_cmd.log
