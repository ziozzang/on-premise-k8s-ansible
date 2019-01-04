#!/bin/bash
WORK_DIR="./works"

if [[ "$(docker images | grep debbuilder | wc -l)" -eq "0" ]]; then
  docker build -t debbuilder .
fi

get_latest_github_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

DATES_STR=`LC_ALL=c date "+%a %b %d %Y"`

#- Install Helm
HELM_VERSION=${HELM_VERSION:-"$(get_latest_github_release 'helm/helm' | tr -dc '\.0-9')"}
HELM_ARCH=${HELM_ARCH:-"linux-amd64"}


#- Helm Version Strips
HELM_VERSION_TMP="$(echo "${HELM_VERSION}"| grep -o -E '[0-9\.\-]+')"


mkdir -p ${WORK_DIR}/DEBIAN

#- Generate Control File
cat  control.template | \
 sed "s;_DATES_HERE_;${DATES_STR};g" | \
 sed "s;_HELM_VERSION_;${HELM_VERSION_TMP};g" | \
 cat > ${WORK_DIR}/DEBIAN/control

cp -f scripts/* ${WORK_DIR}/DEBIAN/


CURRENT_DIR=`pwd`
echo "PWD: ${CURRENT_DIR}"

mkdir -p tmp
cd tmp 
curl https://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION_TMP}-${HELM_ARCH}.tar.gz | tar xvzf -
cd ..

mkdir -p ${WORK_DIR}/usr/bin/
cp -f ./tmp/${HELM_ARCH}/{helm,tiller} ${WORK_DIR}/usr/bin/
chmod 0755 ${WORK_DIR}/usr/bin/{helm,tiller}
chown root:root  ${WORK_DIR}/usr/bin/*
rm -rf ./tmp/


#- Builds
docker run -it --rm \
  -e HELM_VERSION="${HELM_VERSION_TMP}" \
  -w /root \
  -v `pwd`:/root debbuilder bash -c "cd /root && dpkg -b /root/works"

mkdir -p DEBS
mv works.deb DEBS/helm-${HELM_VERSION_TMP}.deb
rm -rf ${WORK_DIR}
