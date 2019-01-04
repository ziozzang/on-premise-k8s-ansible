#!/bin/bash

if [[ "$(docker images | grep rpmbuilder | wc -l)" -eq "0" ]]; then
  docker build -t rpmbuilder .
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


#- Generate RPM Spec File
cat kubehosts.spec.template | \
 sed "s;_DATES_HERE_;${DATES_STR};g" | \
 sed "s;_CNI_VERSION_;${CNI_VERSION_TMP};g" | \
 sed "s;_CRICTL_VERSION_;${CRICTL_VERSION_TMP};g" | \
 sed "s;_KUBE_RELEASE_;${KUBE_RELEASE_TMP};g" | \
 cat > kubehosts.spec

#- Builds
docker run -it --rm \
  -e CRICTL_VERSION="${CRICTL_VERSION}" \
  -e CNI_VERSION="${CNI_VERSION}" \
  -e KUBE_RELEASE="${KUBE_RELEASE}" \
  -v `pwd`:/root rpmbuilder rpmbuild -ba /root/kubehosts.spec

mkdir -p RPMS
cp -f rpmbuild/RPMS/x86_64/* RPMS/
rm -rf rpmbuild kubehosts.spec
