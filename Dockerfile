FROM idein/golang:1.14-buster

# Install dependencies
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y git protobuf-compiler btrfs-tools libbtrfs-dev libseccomp-dev build-essential pkg-config fakeroot

# raspbian, armv6l
ENV GOOS linux
ENV GOARCH arm
ENV GOARM 6

# Build runc
ARG RUNC_VERSION_TAG="v1.0.0-rc10"
RUN go get -d github.com/opencontainers/runc \
 && cd ${GOPATH}/src/github.com/opencontainers/runc/ \
 && git checkout ${RUNC_VERSION_TAG} \
 && make \
 && make install BINDIR=/root/pkgroot/usr/sbin

# Build containerd
ARG CONTAINERD_VERSION_TAG="v1.2.13"
RUN go get -d github.com/containerd/containerd \
 && cd ${GOPATH}/src/github.com/containerd/containerd \
 && git checkout ${CONTAINERD_VERSION_TAG} \
 && make \
 && make install DESTDIR=/root/pkgroot/usr

ADD debian    /root/pkgroot/DEBIAN
ADD usr/share /root/pkgroot/usr/share
ADD lib       /root/pkgroot/lib
ADD etc       /root/pkgroot/etc

ENTRYPOINT ["fakeroot","dpkg-deb","--build","/root/pkgroot","/root/deb"]
