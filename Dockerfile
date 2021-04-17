FROM arm64v8/debian:buster-slim

ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN set -x

RUN apt-get update \
    && apt-get install --no-install-recommends -y systemd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm -f /var/run/nologin

RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/lib/systemd/systemd"]

RUN apt-get update \
    && apt-get install --no-install-recommends -y apt-utils sudo vim gawk coreutils \
       openssh-server openssh-client psmisc iptables iproute2 dnsmasq \
       net-tools rsyslog equivs equivs devscripts dpkg-dev dialog # qemu-system-x86

SHELL ["/bin/bash", "-c"]

RUN dpkg --add-architecture amd64 \
    && apt-get update \
    && apt-get install --no-install-recommends -y libc6:amd64 \
    && apt-get install --no-install-recommends -y qemu qemu-user qemu-user-static binfmt-support

RUN apt-get install -y xterm
RUN apt-get install -y curl wget unzip

WORKDIR /cf

ARG URL=https://ci.android.com/builds/latest/branches/aosp-master-throttled/targets/aosp_cf_arm64_phone-userdebug/view/BUILD_INFO

RUN RURL=$(curl -Ls -o /dev/null -w %{url_effective} ${URL}) \
    && IMG=aosp_cf_arm64_phone-img-$(echo $RURL | awk -F\/ '{print $6}').zip \
	&& wget -nv ${RURL%/view/BUILD_INFO}/raw/${IMG} \
    && wget -nv ${RURL%/view/BUILD_INFO}/raw/cvd-host_package.tar.gz \
	&& unzip $IMG \
	&& tar xvf cvd-host_package.tar.gz \
	&& rm -v $IMG cvd-host_package.tar.gz

RUN apt-get install -y git

WORKDIR /root
RUN git clone https://github.com/google/android-cuttlefish

# build .deb packages
WORKDIR /root/android-cuttlefish
RUN yes | mk-build-deps -i -r -B
RUN dpkg-buildpackage -uc -us
RUN ls -al

RUN apt-get install --no-install-recommends -y -f ../cuttlefish-common_*.deb \
    && rm -rvf ../cuttlefish-common_*.deb 

RUN usermod -aG cvdnetwork root && usermod -aG kvm root

# copy root filesystem
WORKDIR /root

CMD /bin/bash
