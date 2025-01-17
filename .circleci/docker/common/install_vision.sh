#!/bin/bash

set -ex

install_ubuntu() {
  apt-get update
  apt-get install -y --no-install-recommends \
          libopencv-dev \
          libavcodec-dev

  # Cleanup
  apt-get autoclean && apt-get clean
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
}

install_centos() {
  # Need EPEL for many packages we depend on.
  # See http://fedoraproject.org/wiki/EPEL
  if [[ $OS_VERSION == 9 ]]; then
      yum install -y epel-release
  else
      yum --enablerepo=extras install -y epel-release
      yum install -y \
          opencv-devel \
          ffmpeg-devel
  fi

  # Cleanup
  yum clean all
  rm -rf /var/cache/yum
  rm -rf /var/lib/yum/yumdb
  rm -rf /var/lib/yum/history
}

OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')

# Install base packages depending on the base OS
ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
case "$ID" in
  ubuntu)
    install_ubuntu
    ;;
  centos)
    install_centos
    ;;
  *)
    echo "Unable to determine OS..."
    exit 1
    ;;
esac
