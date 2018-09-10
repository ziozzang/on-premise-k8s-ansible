#!/bin/bash
# Code by Jioh L. Jung <ziozzang@gmail.com>
# Offline latest Kubernetes installation using docker container.

DOCKER_IMAGE_TAG=${1:-kubebins}

# Get Current Directory for fetching
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

docker_save() {
  TAGS="$1"
  FNAME=`echo "${TAGS}.tgz" | tr '\:\/' _`
  echo ">> Saving: ${TAGS} => images/${FNAME}"
  docker pull ${TAGS}
  docker save ${TAGS} | gzip > "./images/${FNAME}"
  docker rmi -f ${TAGS}
}

# Remove temporary directorys
rm -rf ./etc ./opt

# Remove unused container images
docker images | awk '{print $3}' | xargs docker rmi -f

# make dirs
mkdir -p ./opt/cni/bin ./opt/bin ./etc/systemd/system/kubelet.service.d/

# Get Latest busybox binary
docker pull busybox
#docker run --rm -v "${CURRENT_DIR}/bin/:/tmp" alpine sh -c "cp -f /bin/busybox /tmp/"

# Fetch CNI
CNI_VERSION_TMP=`get_latest_release "containernetworking/plugins"`
CNI_VERSION="${CNI_VERSION:-${CNI_VERSION_TMP}}"
echo "Latest CNI Version: ${CNI_VERSION}"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C ./opt/cni/bin -xz

# Fetch CRICTL
CRICTL_VERSION_TMP=`get_latest_release "kubernetes-sigs/cri-tools"`
CRICTL_VERSION="${CRICTL_VERSION:-${CRICTL_VERSION_TMP}}"
echo "Latest CRICTL version: ${CRICTL_VERSION}"
curl -L "https://github.com/kubernetes-incubator/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | tar -C ./opt/bin -xz

# Fetch kube*
KUBE_RELEASE_TMP="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
KUBE_RELEASE="${KUBE_RELEASE:-${KUBE_RELEASE_TMP}}"
echo "Kube* tools version: ${KUBE_RELEASE}"

#- Fetch Services files. (for systemd)
cd "${CURRENT_DIR}"
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBE_RELEASE}/build/debs/kubelet.service" | sed "s:/usr/bin:/opt/bin:g" > ./etc/systemd/system/kubelet.service
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBE_RELEASE}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/opt/bin:g" > ./etc/systemd/system/kubelet.service.d/10-kubeadm.conf

#- Fetch kubeadm, kubelet, kubectl
cd ./opt/bin
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${KUBE_RELEASE}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

# Fetch Proper version of Container Images
#- Generate temporary files
TEMP_FILES=$(mktemp /tmp/output.XXXXXXXXXX)

#- Get current kubernetes image list
cd "${CURRENT_DIR}"
docker run --rm -v `pwd`/opt/bin/:/opt/bin \
  alpine sh -c "apk update >/dev/null && apk add -f curl wget >/dev/null && /opt/bin/kubeadm config images list" \
  > ${TEMP_FILES}

#- Fetch / package
while read p; do
  docker_save ${p}
done < ${TEMP_FILES}

#- Remove temporary file
rm -f "${TEMP_FILES}"


# Get Kubernetes Dashboard
DASHBOARD_RELEASE_TMP=`get_latest_release kubernetes/dashboard`
DASHBOARD_RELEASE="${DASHBOARD_RELEASE:-${DASHBOARD_RELEASE_TMP}}"
echo "> DASHBOARD VERSION: ${DASHBOARD_RELEASE}"
docker_save gcr.io/google_containers/kubernetes-dashboard-amd64:${DASHBOARD_RELEASE}

# Get Additional Containers
#TODO/WIP
#docker pull weaveworks/weave-npc:1.8.2
#docker pull weaveworks/weave-kube:1.8.2
#https://github.com/kubernetes/kubernetes/blob/master/cluster/addons/addon-manager/Makefile -> VERSION
#docker pull gcr.io/google-containers/kube-addon-manager:v6.1
#docker pull gcr.io/google_containers/dnsmasq-metrics-amd64:1.0
#docker pull gcr.io/google_containers/kubedns-amd64:1.8
#docker pull gcr.io/google_containers/kube-dnsmasq-amd64:1.4
#docker pull gcr.io/google_containers/kube-discovery-amd64:1.0
#docker pull quay.io/coreos/flannel-git:v0.6.1-28-g5dde68d-amd64
#docker pull gcr.io/google_containers/exechealthz-amd64:1.2


# Fetch Services files. (for systemd)
cd "${CURRENT_DIR}"
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBE_RELEASE}/build/debs/kubelet.service" | sed "s:/usr/bin:/opt/bin:g" > ./etc/systemd/system/kubelet.service
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBE_RELEASE}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/opt/bin:g" > ./etc/systemd/system/kubelet.service.d/10-kubeadm.conf

docker build -t "${DOCKER_IMAGE_TAG}" .
