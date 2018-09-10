FROM docker
RUN apk update && apk upgrade && \
    apk add gzip bash curl wget grep busybox-extras && \
    mkdir -p /images /files/bin /files/opt /files/etc && \
    ln -s /files/opt /opt && ln -s /files/etc/systemd /etc/systemd && \
    rm -rf /var/cache/apk/*
COPY ./bin /files/bin
COPY ./opt /files/opt
COPY ./etc /files/etc
COPY ./images /images

# kubeadm config images list >
