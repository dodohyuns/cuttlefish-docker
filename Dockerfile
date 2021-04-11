FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y build-essential grub-efi-ia32-bin unzip curl wget

# needed for debuild
RUN apt-get install -y devscripts

# build dependencies
RUN apt-get install -y config-package-dev debhelper-compat

# install dependencies
RUN apt-get install -y bridge-utils dnsmasq-base f2fs-tools iptables libarchive-tools libdrm2 libfdt1 libgl1 libusb-1.0-0 libwayland-client0 libwayland-server0 net-tools python2.7

# a syslog is required for crosvm to run
RUN apt-get install -y rsyslog

# user needs to be member of these groups
RUN groupadd cvdnetwork && groupadd kvm && usermod -aG cvdnetwork root && usermod -aG kvm root

# clone cuttlefish
WORKDIR /cf

ARG URL=https://ci.android.com/builds/latest/branches/aosp-master-throttled/targets/aosp_cf_arm64_phone-userdebug/view/BUILD_INFO

RUN RURL=$(curl -Ls -o /dev/null -w %{url_effective} ${URL}) \
    && IMG=aosp_cf_arm64_phone-img-$(echo $RURL | awk -F\/ '{print $6}').zip \
	&& wget -nv ${RURL%/view/BUILD_INFO}/raw/${IMG} \
    && wget -nv ${RURL%/view/BUILD_INFO}/raw/cvd-host_package.tar.gz \
	&& unzip $IMG -d aosp_cf_arm64_phone-img \
	&& tar xvf cvd-host_package.tar.gz \
	&& rm -v $IMG cvd-host_package.tar.gz

WORKDIR /root
RUN git clone https://github.com/google/android-cuttlefish

# build .deb packages
WORKDIR /root/android-cuttlefish
RUN debuild -i -us -uc -b

# install .deb packages
RUN dpkg -i ../cuttlefish-common_*_amd64.deb
RUN apt-get install -f

# copy root filesystem
WORKDIR /root

CMD /bin/bash