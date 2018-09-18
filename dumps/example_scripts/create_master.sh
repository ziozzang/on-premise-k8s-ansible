#!/bin/bash
# This script is sample master build

LOG_FILE=$(mktemp /tmp/output.XXXXXXXXXX)
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Reset Kubernetes
kubeadm reset -f
rm -fr $HOME/.kube logs
docker images | awk '{print $3}' | xargs docker rmi -f
docker load < /tmp/kubebins.tar

# Copy & Dump files
docker run \
  --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /:/host \
  --privileged \
  kubebins

if [ `echo "${PATH}" | grep "/opt/bin" | wc -l` -eq "0" ]; then
  export PATH=$PATH:/opt/bin
fi

if [ `grep 'PATH' ~/.bashrc | grep '/opt/bin' | wc -l` -eq "0" ]; then
  echo 'export PATH=$PATH:/opt/bin' >> ~/.bashrc
fi

# Restart
swapoff -a
kubeadm init --config=/opt/config.yml | tee ${LOG_FILE}

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

cd "${CURRENT_DIR}"
LOGS=`grep "kubeadm join" ${LOG_FILE}`
echo "RUN>> ${LOGS}"
echo "${LOGS}" > join_cmd.log
