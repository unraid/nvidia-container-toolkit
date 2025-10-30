FROM debian:buster-slim

RUN echo "deb http://archive.debian.org/debian/ buster main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security/ buster/updates main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  wget \
  curl \
  ca-certificates \
  git \
  build-essential \
  dh-make \
  fakeroot \
  devscripts \
  lsb-release && \
  rm -rf /var/lib/apt/lists/*

ENV OS_ARCH="amd64"
ENV GOLANG_VERSION="1.22.5"
RUN curl https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-${OS_ARCH}.tar.gz | tar -C /usr/local -xz
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
ENV DATA_DIR=/tmp

COPY config.toml /opt/config.toml

RUN chmod -R 777 /opt

ENV GPG_TTY=/dev/console

CMD bash -c "cd ${DATA_DIR} && \
  mkdir -p ${DATA_DIR}/go/src/github.com/NVIDIA && \
  cd ${DATA_DIR}/go/src/github.com/NVIDIA && \
  git clone --depth 1 --branch v${TOOLKIT_VERSION} https://github.com/NVIDIA/nvidia-container-toolkit && \
  cd ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit && \
  git checkout v${TOOLKIT_VERSION} && \
  mkdir -p ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/usr/bin && \
  sed -i '/if err := updateLdCache(os\.Args); err != nil/,+3d' ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit/cmd/nvidia-cdi-hook/update-ldcache/update-ldcache.go && \
  sed -i '/func updateLdCacheHandler() {/a\\\\tvar _ = log.Printf' ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit/cmd/nvidia-cdi-hook/update-ldcache/update-ldcache.go && \
  make LIBNVIDIA_CONTAINER_VERSION=${TOOLKIT_VERSION} LIBNVIDIA_CONTAINER_TAG=${TOOLKIT_VERSION} binaries && \
  cp ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit/nvidia-container-runtime-hook ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/usr/bin && \
  cp ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit/nvidia-container-runtime ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/usr/bin && \
  cp ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit/nvidia-ctk ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/usr/bin && \
  cp ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit/nvidia-cdi-hook ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/usr/bin && \
  cp ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit/nvidia-container-runtime.cdi ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/usr/bin && \
  cp ${DATA_DIR}/go/src/github.com/NVIDIA/nvidia-container-toolkit/nvidia-container-runtime.legacy ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/usr/bin && \
  cd ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/usr/bin && \
  ln -s nvidia-container-runtime-hook nvidia-container-toolkit && \
  mkdir -p ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/etc/nvidia-container-runtime && \
  cp /opt/config.toml ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION}/etc/nvidia-container-runtime/config.toml && \
  cd ${DATA_DIR}/nvidia-container-toolkit-${TOOLKIT_VERSION} && \
  mkdir ${DATA_DIR}/v${TOOLKIT_VERSION} && \
  tar cfvz ${DATA_DIR}/v${TOOLKIT_VERSION}/nvidia-container-toolkit-v${TOOLKIT_VERSION}.tar.gz *"
