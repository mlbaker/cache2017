FROM centos:7

MAINTAINER Michael Baker <michael.baker@apexdatasolutions.net>

# update OS + dependencies & run Caché silent instal
RUN yum -y update \
 && yum -y install which tar hostname net-tools wget \
 && yum -y clean all \ 
 && ln -sf /etc/locatime /usr/share/zoneinfo/America/New_York

ARG password="isc"
ARG cache=cache-2017.1.0.792.0

ENV TMP_INSTALL_DIR=/tmp/distrib

# vars for Caché silent install
ENV ISC_PACKAGE_INSTANCENAME="CACHE" \
    ISC_PACKAGE_INSTALLDIR="/opt/cache2017" \
    ISC_PACKAGE_UNICODE="Y" \
    ISC_PACKAGE_CLIENT_COMPONENTS="" \
    ISC_PACKAGE_INITIAL_SECURITY="Normal" \
    ISC_PACKAGE_USER_PASSWORD=${password} 

# set-up and install Caché from distrib_tmp dir 
WORKDIR ${TMP_INSTALL_DIR}

COPY cache.key $ISC_PACKAGE_INSTALLDIR/mgr/
COPY %ZSTART.mac /tmp/
COPY ccontrol-wrapper.sh /usr/bin/

ADD $cache-lnxrhx64.tar.gz .

# cache distributive
RUN ./$cache-lnxrhx64/cinstall_silent \
 && ccontrol stop $ISC_PACKAGE_INSTANCENAME quietly \
# Caché container main process PID 1 (https://github.com/zrml/ccontainermain)
 && curl -L https://github.com/daimor/ccontainermain/raw/master/distrib/linux/ccontainermain -o /ccontainermain \
 && chmod +x /ccontainermain \
 && rm -rf $TMP_INSTALL_DIR \
 && cd /usr/bin \
 && rm ccontrol \
 && mv ccontrol-wrapper.sh ccontrol \
 && chmod 555 ccontrol \
 && ccontrol start $ISC_PACKAGE_INSTANCENAME \
 && printf "_SYSTEM\n$ISC_PACKAGE_USER_PASSWORD\n" \
 |  csession $ISC_PACKAGE_INSTANCENAME -U %SYS "##class(%SYSTEM.OBJ).Load(\"/tmp/%ZSTART.mac\",\"cdk\")" \
 && ccontrol stop $ISC_PACKAGE_INSTANCENAME quietly \
 && sed -i 's/^MaxServerConn=1/MaxServerConn=10/' /opt/cache2017/cache.cpf \
 && rm -rf /tmp/%ZSTART.mac

WORKDIR ${ISC_PACKAGE_INSTALLDIR}

# TCP sockets that can be accessed if user wants to (see 'docker run -p' flag)
EXPOSE 57772 1972

ENTRYPOINT ["/ccontainermain", "-cconsole", "-i", "cache"]