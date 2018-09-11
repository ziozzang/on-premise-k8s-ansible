FROM docker
RUN apk update && apk upgrade && \
    apk add gzip bash curl wget grep busybox-extras && \
    mkdir -p /images /files/bin /files/opt/pkg /files/opt/pkg_dl /files/etc && \
    ln -s /files/opt /opt && ln -s /files/etc/systemd /etc/systemd && \
    rm -rf /var/cache/apk/*
COPY ./bin /files/bin
COPY ./opt /files/opt
COPY ./etc /files/etc
COPY ./images /images
COPY ./pkg /files/opt/pkg
COPY ./pkg_dl /files/opt/pkg_dl
ENTRYPOINT bash /files/bin/entrypoint.sh
