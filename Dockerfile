FROM golang:1.13.8-alpine3.11 AS builder

ARG CONMON_VERSION
ARG RUNC_VERSION
ARG CNI_PLUGINS_VERSION
ARG PODMAN_VERSION

# RUN echo -e http://mirrors.tuna.tsinghua.edu.cn/alpine/v3.11/main/ > /etc/apk/repositories
RUN apk --no-cache add bash btrfs-progs-dev build-base device-mapper git glib-dev go-md2man gpgme-dev ip6tables libassuan-dev libseccomp-dev libselinux-dev lvm2-dev openssl ostree-dev pkgconf protobuf-c-dev protobuf-dev
RUN git config --global advice.detachedHead false

RUN git clone --branch v$CONMON_VERSION https://github.com/containers/conmon $GOPATH/src/github.com/containers/conmon && \
    cd $GOPATH/src/github.com/containers/conmon && make
RUN git clone --branch v$RUNC_VERSION https://github.com/opencontainers/runc $GOPATH/src/github.com/opencontainers/runc && \
    cd $GOPATH/src/github.com/opencontainers/runc && EXTRA_LDFLAGS="-s -w" make BUILDTAGS="seccomp apparmor selinux ambient"
RUN git clone --branch v$CNI_PLUGINS_VERSION https://github.com/containernetworking/plugins $GOPATH/src/github.com/containernetworking/plugins && \
    cd $GOPATH/src/github.com/containernetworking/plugins && GOFLAGS="-ldflags=-s -ldflags=-w" ./build_linux.sh
# RUN git clone --branch v$PODMAN_VERSION https://github.com/chenliu1993/podman $GOPATH/src/github.com/chenliu1993/podman && \
#     cd $GOPATH/src/github.com/chenliu1993/podman && LDFLAGS="-s -w" make varlink_generate <BIN> BUILDTAGS="selinux seccomp apparmor"
RUN git clone https://github.com/chenliu1993/podman $GOPATH/src/github.com/chenliu1993/podman && \
    cd $GOPATH/src/github.com/chenliu1993/podman && LDFLAGS="-s -w" make varlink_generate <BIN> BUILDTAGS="selinux seccomp apparmor"

FROM alpine:3.11.3

ARG CREATED
ARG REVISION
ARG PODMAN_VERSION
ARG IMAGE_NAME

LABEL maintainer="Jeff Wu <jeff.wu.junfei@gmail.com>"

LABEL org.opencontainers.image.created=$CREATED \
    org.opencontainers.image.revision=$REVISION \
    org.opencontainers.image.version=$PODMAN_VERSION \
    org.opencontainers.image.title=$IMAGE_NAME \
    org.opencontainers.image.source="https://github.com/jeffwubj/podman" \
    org.opencontainers.image.url="https://podman.io"

RUN apk --no-cache add device-mapper gpgme ip6tables libseccomp libselinux ostree tzdata

COPY --from=builder /go/src/github.com/containers/conmon/bin/ /usr/bin/
COPY --from=builder /go/src/github.com/opencontainers/runc/runc /usr/bin/
COPY --from=builder /go/src/github.com/containernetworking/plugins/bin/ /usr/lib/cni/
COPY --from=builder /go/src/github.com/chenliu1993/podman/bin/ /usr/bin/

COPY files/87-podman-bridge.conflist /etc/cni/net.d/
COPY files/containers.conf files/registries.conf files/policy.json files/storage.conf /etc/containers/

ENTRYPOINT ["<BIN>"]
CMD ["help"]
