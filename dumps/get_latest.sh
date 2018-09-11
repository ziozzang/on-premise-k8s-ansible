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
  # Strip ' or " character
  TAGS=`echo "$1" | sed "s/'//g" | sed 's/"//g'`
  # Replace : or / to _ (Docker tags are converted into plain file name)
  FNAME=`echo "${TAGS}.tgz" | tr '\:\/' _`

  if [[ -f "images/${FNAME}" ]]; then
    echo ">> File Exist. Skipping => images/${FNAME}"
  else
    echo ">> Saving: ${TAGS} => images/${FNAME}"
    docker pull ${TAGS}
    docker save ${TAGS} | gzip > "./images/${FNAME}"
    docker rmi -f ${TAGS}
  fi
}

# Remove temporary directorys
rm -rf ./etc ./opt ./pkg ./pkg_dl

# Remove unused container images
docker images | awk '{print $3}' | xargs docker rmi -f

# make dirs
# > pkg: packages to install
# > pkg_dl: packages to download only
# > images: downloaded images
# > /opt/bin: binaries
# > /etc: systemd files
mkdir -p ./pkg ./pkg_dl ./images ./opt/cni/bin ./opt/bin ./etc/systemd/system/kubelet.service.d/

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


# Get Kubernetes Packages
if [[ -f "pkg.list" ]]; then
  cd "${CURRENT_DIR}/pkg"
  grep . ../pkg.list | grep -v -e "^#" | xargs -I X curl --location -J -O X
  cd "${CURRENT_DIR}"
fi

if [[ -f "pkg_dl.list" ]]; then
  cd "${CURRENT_DIR}/pkg_dl"
  grep . ../pkg_dl.list | grep -v -e "^#" | xargs -I X curl --location -J -O X
  cd "${CURRENT_DIR}"
fi

# Get Pkg's images
cd "${CURRENT_DIR}"

#- Generate temporary files
TEMP_FILES=$(mktemp /tmp/output.XXXXXXXXXX)

grep -HR 'image\:' ./pkg/ ./pkg_dl/ | grep -v -E '(-mip|-arm|-ppc|-s390)' | awk '{print $3}' > ${TEMP_FILES}

#- Fetch / package
while read p; do
  docker_save ${p}
done < ${TEMP_FILES}

#- Remove temporary file
rm -f "${TEMP_FILES}"

# Fetch for Support Binary(Esp. Static compiled bins)
curl -o ./opt/bin/socat https://github.com/andrew-d/static-binaries/raw/master/binaries/linux/x86_64/socat && chmod +x ./opt/bin/socat

docker build -t "${DOCKER_IMAGE_TAG}" .
