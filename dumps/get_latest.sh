#!/bin/bash
# Code by Jioh L. Jung <ziozzang@gmail.com>

DOCKER_IMAGE_TAG=${1:-kubebins}

# Get Current Directory for fetching
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

# Remove temporary directorys
rm -rf ./bin ./etc ./opt

# make dirs
mkdir -p ./opt/cni/bin ./opt/bin ./etc/systemd/system/kubelet.service.d/

# Get Latest busybox binary
docker pull busybox
#docker run --rm -v "${CURRENT_DIR}/bin/:/tmp" busybox sh -c "cp -f /bin/busybox /tmp/"

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
cd ./opt/bin
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${KUBE_RELEASE}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

# Fetch Services
cd "${CURRENT_DIR}"
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBE_RELEASE}/build/debs/kubelet.service" | sed "s:/usr/bin:/opt/bin:g" > ./etc/systemd/system/kubelet.service
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBE_RELEASE}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/opt/bin:g" > ./etc/systemd/system/kubelet.service.d/10-kubeadm.conf

docker build -t "${DOCKER_IMAGE_TAG}" .
