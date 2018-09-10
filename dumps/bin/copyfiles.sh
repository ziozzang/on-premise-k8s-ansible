#!/bin/bash
# Install file into host files

HOST_DIR="/host"

if [ ! -d "${HOST_DIR}" ]; then
  echo "Neet mount host root -> ${HOST_DIR}"
  exit 1
fi
mkdir -p ${HOST_DIR}/opt

cp -f /files/opt/* ${HOST_DIR}/opt/
cp -f /files/etc/systemd/* ${HOST_DIR}/etc/systemd/

echo ">> Need setup params <<"
echo "export PATH=$PATH:/opt/bin"
echo "systemctl enable kubelet && service kubelet start"
