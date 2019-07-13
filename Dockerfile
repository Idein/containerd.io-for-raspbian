FROM idein/actcast-rpi-app-base:buster

# git tag
ARG RUNC_VERSION_TAG="v1.0.0-rc8"
ARG CONTAINERD_VERSION_TAG="v1.2.7"

# raspbian, armv6l
ENV GOOS linux
ENV GOARCH arm
ENV GOARM 6

# Install dependencies
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y git golang-go protobuf-compiler btrfs-tools libbtrfs-dev libseccomp-dev build-essential pkg-config fakeroot

# Build runc
RUN go get -d github.com/opencontainers/runc \
 && cd go/src/github.com/opencontainers/runc/ \
 && git checkout ${RUNC_VERSION_TAG} \
 && make \
 && make install BINDIR=/root/pkgroot/usr/sbin

# Build containerd
RUN go get -d github.com/containerd/containerd \
 && cd go/src/github.com/containerd/containerd \
 && git checkout ${CONTAINERD_VERSION_TAG} \
 && make GO_BUILD_FLAGS='-N -l' \
 && make install DESTDIR=/root/pkgroot/usr

ADD debian    /root/pkgroot/DEBIAN
ADD usr/share /root/pkgroot/usr/share
ADD lib       /root/pkgroot/lib
ADD etc       /root/pkgroot/etc

ENTRYPOINT ["fakeroot","dpkg-deb","--build","/root/pkgroot","/root/deb"]
