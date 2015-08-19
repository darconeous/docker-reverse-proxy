#!/bin/bash

VHOSTNUMBER=0

add-http-vhost () {
	local name=vhost-$((VHOSTNUMBER++))
	local address=$1
	local port=$2
	shift
	shift
	
	(
		echo "cache_peer ${address} parent ${port} 0 no-query proxy-only name=${name}"
		echo "#cache_peer_domain ${name} dstdomain $*"
		echo "acl ${name}-acl dstdomain $*"
		echo "http_access allow ${name}-acl"
		echo "cache_peer_access ${name} allow ${name}-acl"
		echo "#cache_peer_access ${name} deny all"
	) >> /etc/squid/squid-custom.conf
}

http-listen () {
	local port=$1
	(
		echo "http_port ${port} accel vhost"
	) >> /etc/squid/squid-custom.conf
}

https-listen () {
	local port=$1
	(
		echo "https_port ${port} accel vhost cert=/etc/ssl/certs/host.crt.pem key=/etc/ssl/private/host.key.pem options=NO_SSLv3,NO_TLSv1,SINGLE_DH_USE capath=/etc/ssl/certs"
	) >> /etc/squid/squid-custom.conf
}

###################################################

[ -f /etc/ssl/certs/host.crt.pem ] || {
	openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/ssl/private/host.key.pem -out /etc/ssl/certs/host.crt.pem -config self-signed-cert.cfg
}

if [ -f /etc/squid/squid-prefix.conf ]
then cat /etc/squid/squid-prefix.conf /etc/squid/squid.conf > /etc/squid/squid-custom.conf
else cat /etc/squid/squid.conf > /etc/squid/squid-custom.conf
fi

cat /etc/squid/squid.conf > /etc/squid/squid-custom.conf

###################################################

. /etc/reverse-proxy/reverse-proxy.conf

###################################################

exec /usr/sbin/squid -d 1 -N -f /etc/squid/squid-custom.conf
