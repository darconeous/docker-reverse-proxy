FROM debian:wheezy

ENV DEBIAN_FRONTEND noninteractive

ADD squid-openssl.patch squid-openssl.patch

RUN apt-get -y update \
	&& DEBIAN_FRONTEND=noninteractive \
		apt-get -y install devscripts build-essential fakeroot libssl-dev \
	&& ( cat /etc/apt/sources.list | sed 's/^deb /deb-src /' > temp ) \
	&& cat temp >> /etc/apt/sources.list \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y update \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y source squid \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y build-dep squid \
	&& cd squid*/ \
	&& ( patch -l -p1 < /squid-openssl.patch ) \
	&& DEBIAN_FRONTEND=noninteractive dpkg-buildpackage \
	&& cd .. \
	&& ( dpkg -i *.deb ; DEBIAN_FRONTEND=noninteractive apt-get -y -f install ) \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y purge devscripts build-essential fakeroot libssl-dev \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y autoremove \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y clean \
	&& rm -fr squid* \
	&& true

EXPOSE 80/tcp 443/tcp 8080/tcp 8081/tcp

ADD squid.conf /etc/squid/squid.conf
ADD self-signed-cert.cfg self-signed-cert.cfg
ADD start.sh /start.sh
RUN chmod +x /start.sh

ADD reverse-proxy.conf /etc/reverse-proxy/reverse-proxy.conf

# For debugging
#RUN apt-get -y install procps vim tmux man less net-tools

VOLUME ["/etc/ssl/certs", "/etc/ssl/private", "/etc/reverse-proxy"]

CMD ["/start.sh"]

