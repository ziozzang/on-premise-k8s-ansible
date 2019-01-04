#!/bin/bash
WORK_DIR="./works"

if [[ "$(docker images | grep debbuilder | wc -l)" -eq "0" ]]; then
  docker build -t debbuilder .
fi

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

#- Acquire Newest Version
CNI_VERSION="${CNI_VERSION:-$(get_latest_release "containernetworking/plugins")}"
CRICTL_VERSION="${CRICTL_VERSION:-$(get_latest_release "kubernetes-sigs/cri-tools")}"
KUBE_RELEASE="${KUBE_RELEASE:-$(curl -sSL https://dl.k8s.io/release/stable.txt)}"

DATES_STR=`LC_ALL=c date "+%a %b %d %Y"`

#- Extract Version String Only
CNI_VERSION_TMP="$(echo "${CNI_VERSION}"| grep -o -E '[0-9\.\-]+')"
CRICTL_VERSION_TMP="$(echo "${CRICTL_VERSION}"| grep -o -E '[0-9\.\-]+')"
KUBE_RELEASE_TMP="$(echo "${KUBE_RELEASE}"| grep -o -E '[0-9\.\-]+')"

mkdir -p ${WORK_DIR}/DEBIAN

#- Generate Control File
cat  control.template | \
 sed "s;_DATES_HERE_;${DATES_STR};g" | \
 sed "s;_CNI_VERSION_;${CNI_VERSION_TMP};g" | \
 sed "s;_CRICTL_VERSION_;${CRICTL_VERSION_TMP};g" | \
 sed "s;_KUBE_RELEASE_;${KUBE_RELEASE_TMP};g" | \
 cat > ${WORK_DIR}/DEBIAN/control

cp -f scripts/* ${WORK_DIR}/DEBIAN/

#- Package files builder
get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

CURRENT_DIR=`pwd`
echo "PWD: ${CURRENT_DIR}"
# Make Directories

mkdir -p ${WORK_DIR}/usr/bin
mkdir -p ${WORK_DIR}/etc/systemd/system/
mkdir -p ${WORK_DIR}/etc/systemd/system/kubelet.service.d/
mkdir -p ${WORK_DIR}/etc/kubernetes/bin
mkdir -p ${WORK_DIR}/usr/local/bin

# Fetch CNI
CNI_VERSION="${CNI_VERSION:-$(get_latest_release "containernetworking/plugins")}"
echo "Latest CNI Version: ${CNI_VERSION}"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | \
  tar -C ${WORK_DIR}/usr/local/bin -xz

# Fetch CRICTL
CRICTL_VERSION="${CRICTL_VERSION:-$(get_latest_release "kubernetes-sigs/cri-tools")}"
echo "Latest CRICTL version: ${CRICTL_VERSION}"
curl -L "https://github.com/kubernetes-incubator/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | \
  tar -C ${WORK_DIR}/usr/bin -xz

# Fetch kube*
KUBE_RELEASE="${KUBE_RELEASE:-$(curl -sSL https://dl.k8s.io/release/stable.txt)}"
echo "Kube* tools version: ${KUBE_RELEASE}"

#- Fetch Services files. (for systemd)

cd "${CURRENT_DIR}"
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBE_RELEASE}/build/debs/kubelet.service" | \
  sed "s:^ExecStart=:ExecStartPre=/etc/kubernetes/bin/kubelet.prepare"$'\\\n'"ExecStart=:g" | \
  cat > ${WORK_DIR}/etc/systemd/system/kubelet.service
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBE_RELEASE}/build/debs/10-kubeadm.conf" | \
  cat > ${WORK_DIR}/etc/systemd/system/kubelet.service.d/10-kubeadm.conf

#- Copy kubelet prepare.
cp -f kubelet.prepare ${WORK_DIR}/etc/kubernetes/bin/

#- Fetch kubeadm, kubelet, kubectl
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${KUBE_RELEASE}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}
mv {kubeadm,kubelet,kubectl} ${WORK_DIR}/usr/bin

#- Modify Files Permission
chmod 0755 ${WORK_DIR}/usr/bin/*
chmod 0755 ${WORK_DIR}/usr/local/bin/*
chmod 0600 ${WORK_DIR}/etc/systemd/system/kubelet.service
chmod 0600 ${WORK_DIR}/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
chmod 0700 ${WORK_DIR}/etc/kubernetes/bin/kubelet.prepare
chown root:root -R ${WORK_DIR}/*

#- Builds
docker run -it --rm \
  -e CRICTL_VERSION="${CRICTL_VERSION}" \
  -e CNI_VERSION="${CNI_VERSION}" \
  -e KUBE_RELEASE="${KUBE_RELEASE}" \
  -w /root \
  -v `pwd`:/root debbuilder bash -c "cd /root && dpkg -b /root/works"

mkdir -p DEBS
mv works.deb DEBS/kubehosts-${KUBE_RELEASE_TMP}.deb
rm -rf ${WORK_DIR}
