FROM debian/wheezy

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update

RUN apt-get -y install devscripts
RUN apt-get -y install build-essential
RUN apt-get -y install fakeroot

RUN cat /etc/apt/sources.list | sed 's/^deb /deb-src /' > temp ; cat temp >> /etc/apt/sources.list ; apt-get -y update
RUN apt-get -y source squid && apt-get -y build-dep squid
RUN apt-get -y install libssl-dev

ADD squid-openssl.patch squid-openssl.patch
RUN cd squid*/ && ( patch -l -p1 < /squid-openssl.patch )

RUN cd squid*/ && dpkg-buildpackage
RUN dpkg -i *.deb ; apt-get -y -f install

RUN apt-get -y clean

EXPOSE 80/tcp 443/tcp 8080/tcp 8081/tcp

ADD squid.conf /etc/squid/squid.conf
ADD self-signed-cert.cfg self-signed-cert.cfg

ADD start.sh /start.sh
RUN chmod +x /start.sh

# For debugging
#RUN apt-get -y install procps vim tmux man less net-tools

ADD reverse-proxy.conf /etc/reverse-proxy/reverse-proxy.conf

VOLUME ["/etc/ssl/certs", "/etc/ssl/private", "/etc/reverse-proxy"]

CMD ["/start.sh"]

