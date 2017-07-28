FROM centos/httpd:latest
MAINTAINER ManageIQ https://github.com/ManageIQ/manageiq-appliance-build

## Atomic/OpenShift Labels
LABEL name="manageiq-apache" \
      vendor="ManageIQ" \
      url="http://manageiq.org/" \
      summary="ManageIQ httpd image" \
      description="ManageIQ is a management and automation platform for virtual, private, and hybrid cloud infrastructures." \
      io.k8s.display-name="ManageIQ Apache" \
      io.k8s.description="ManageIQ Apache is the front-end for the ManageIQ Application." \
      io.openshift.expose-services="443:https" \
      io.openshift.tags="ManageIQ-Apache,apache"

## To cleanly shutdown systemd, use SIGRTMIN+3
STOPSIGNAL SIGRTMIN+3

## Install EPEL repo, yum necessary packages for the build without docs, clean all caches
RUN yum -y install centos-release-scl-rh && \
    yum -y install --setopt=tsflags=nodocs mod_ssl && \
    # SSSD Packages \
    yum -y install --setopt=tsflags=nodocs sssd                         \
                                           sssd-dbus                    \
                                           && \
    # Apache External Authentication Module Packages \
    yum -y install --setopt=tsflags=nodocs mod_auth_kerb                \
                                           mod_authnz_pam               \
                                           mod_intercept_form_submit    \
                                           mod_lookup_identity          \
                                           mod_auth_mellon              \
                                           && \
    # IPA External Authentication Packages \
    yum -y install --setopt=tsflags=nodocs c-ares                       \
                                           certmonger                   \
                                           ipa-client                   \
                                           ipa-admintools               \
                                           && \
    # Active Directory External Authentication Packages \
    yum -y install --setopt=tsflags=nodocs adcli                        \
                                           realmd                       \
                                           real-md                      \
                                           oddjob                       \
                                           oddjob-mkhomedir             \
                                           samba-common                 \
                                           && \
    yum clean all

## Systemd cleanup base image
RUN (cd /lib/systemd/system/sysinit.target.wants && for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -vf $i; done) && \
     rm -vf /lib/systemd/system/multi-user.target.wants/* && \
     rm -vf /etc/systemd/system/*.wants/* && \
     rm -vf /lib/systemd/system/local-fs.target.wants/* && \
     rm -vf /lib/systemd/system/sockets.target.wants/*udev* && \
     rm -vf /lib/systemd/system/sockets.target.wants/*initctl* && \
     rm -vf /lib/systemd/system/basic.target.wants/* && \
     rm -vf /lib/systemd/system/anaconda.target.wants/*

## Remove any existing configurations
RUN rm -f /etc/httpd/conf.d/*

## Changing working directory to the Apache location
WORKDIR /etc/httpd

COPY docker-assets/entrypoint              /usr/bin
COPY docker-assets/initialize_httpd.sh     /usr/bin
COPY docker-assets/generate_server_cert.sh /usr/bin
COPY docker-assets/manageiq.conf           /etc/httpd/conf.d/

RUN chmod +x /usr/bin/initialize_httpd.sh /usr/bin/generate_server_cert.sh

EXPOSE 80 443

RUN systemctl enable dbus httpd

VOLUME [ "/sys/fs/cgroup" ]

ENTRYPOINT [ "entrypoint" ]
CMD [ "/usr/sbin/init" ]
