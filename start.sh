#!/bin/bash

VHOSTNUMBER=0

set -x

add-http-vhost () {
	local name=vhost-$((VHOSTNUMBER++))
	local address=$1
	local port=$2
	shift
	shift
	
	(
		echo "############ HTTP -> $*"
		echo "cache_peer ${address} parent ${port} 0 no-query originserver name=${name}"
		echo "cache_peer_domain ${name} dstdomain $*"
		echo "acl ${name}-acl dstdomain $*"
		echo "http_access allow ${name}-acl"
		echo "cache_peer_access ${name} allow ${name}-acl"
		echo "#cache_peer_access ${name} deny all"
		echo ""
	) >> /etc/squid/squid-custom.conf
}

add-https-vhost () {
	local name=vhost-$((VHOSTNUMBER++))
	local address=$1
	local port=$2
	shift
	shift

	(
		echo "############ HTTPS -> $*"
		echo "cache_peer ${address} parent ${port} 0 no-query originserver ssl sslflags=DONT_VERIFY_PEER name=${name}"
		echo "cache_peer_domain ${name} dstdomain $*"
		echo "acl ${name}-acl dstdomain $*"
		echo "http_access allow ${name}-acl"
		echo "cache_peer_access ${name} allow ${name}-acl"
		echo "#cache_peer_access ${name} deny all"
		echo ""
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
	local cipher="ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK"
	local ssl_options="NO_SSLv3,NO_TLSv1,SINGLE_DH_USE"
	local dhparams=/etc/ssl/certs/dhparam.pem

	[ -f "$dhparams" ] || openssl dhparam -out "$dhparams" 2048

	(
		echo "https_port ${port} accel vhost cert=/etc/ssl/certs/host.crt.pem key=/etc/ssl/private/host.key.pem options=$ssl_options dhparams=$dhparams cipher=$cipher capath=/etc/ssl/certs"
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

exec /usr/sbin/squid -d 10 -N -f /etc/squid/squid-custom.conf
