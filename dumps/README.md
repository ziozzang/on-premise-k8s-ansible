# TL;DR
* Get Latest Version and packing into Docker images(based on busybox).
* Run K8S with Docker in Docker. (Self Dockerized installations)
* No dependancy about Host OS.
* No dependancy about .....

* This code is for copying of kubernetes tools into on-premise environments(esp. no internet connected).

# Usages
* just run get_latest.sh
* You can run with crontab or something for updating.. :)

```
# if some parameter exist, script will use it.
CNI_VERSION="v0.7.1" ./get_latest.sh
```

## Parameters
* DOCKER_IMAGE_TAG: container tag name to build (default: kubebins)
* CNI_VERSION: fetch from https://github.com/containernetworking/plugins/
* CRICTL_VERSION: fetch from https://github.com/kubernetes-incubator/cri-tools/
* KUBE_RELEASE: fetch from https://storage.googleapis.com/kubernetes-release/

## Extract from container images
* You can run just like this

```
docker run --rm -it -v `pwd`/tmp/:/tmp kubebins sh -c "mkdir -p /tmp/etc && cp -rvf /opt /tmp/ && cp -rvf /etc/systemd /tmp/etc/"
```
