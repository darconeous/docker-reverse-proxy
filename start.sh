#!/bin/bash

VHOSTNUMBER=0
#set -x

[ "x${PROXY_CLIENT_CA}" = "x" ] && export PROXY_CLIENT_CA=/etc/ssl/certs/proxy-client-ca.pem

NGINX_CONFIG_FILE=/etc/nginx/conf.d/default.conf

update-ca-certificates
	
export SSL_CIPHER="ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK"
export HOST_SSL_CERT=/etc/ssl/certs/host.crt.pem
export HOST_SSL_KEY=/etc/ssl/private/host.key.pem
export HTTPS_PORT=
export HTTP_PORT=

# FD 3 is the configuration file

die () {
	echo "FATAL: $*"
	exit 1
}

add-server-port-stuff() {
	if [ "x$HTTPS_PORT" != "x" ]
	then
		echo "	listen $HTTPS_PORT ssl;"
		echo "	ssl on;"
        echo "	ssl_certificate ${HOST_SSL_CERT};"
        echo "	ssl_certificate_key ${HOST_SSL_KEY};"
        echo "	ssl_session_timeout  5m;"
        #echo "	ssl_protocols        SSLv3 TLSv1;"
        echo "	ssl_ciphers          $SSL_CIPHER;"
        echo "	ssl_prefer_server_ciphers   on;"
		echo "  ssl_verify_depth 2;"
		
		[ -f "${PROXY_CLIENT_CA}" ] && {
			echo "  ssl_client_certificate ${PROXY_CLIENT_CA};"
			echo "  ssl_verify_client on;"
		}
	else
		echo "	listen $HTTP_PORT;"
	fi
}

add-http-vhost () {
	local address=$1
	local port=$2
	shift
	shift
	
	(
		echo "server {"
		add-server-port-stuff
		echo "	server_name $*;"
		echo "	location / {"
		echo "		proxy_pass http://$address:$port;"
		echo "	}"
		echo "}"
	) 1>&3
}

add-https-vhost () {
	local name=vhost-$((VHOSTNUMBER++))
	local address=$1
	local port=$2
	shift
	shift
	
	(
		echo "server {"
		add-server-port-stuff
		echo "	server_name $*;"
		echo "	location / {"
		echo "		proxy_pass https://$address:$port;"
		echo "	}"
		echo "}"
	) 1>&3
}

http-listen () {
	local port=$1
	export HTTP_PORT=$1
	echo "# http-listen" 1>&3
	
	[ "x$HTTPS_PORT" != "x" ] && require-https
}

https-listen () {
	export HTTPS_PORT=$1
	local dhparams=/etc/ssl/certs/dhparam.pem

	[ -f "$dhparams" ] || openssl dhparam -out "$dhparams" 2048

	[ -f /etc/ssl/certs/host.crt.pem ] || {
		openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/ssl/private/host.key.pem -out /etc/ssl/certs/host.crt.pem -config self-signed-cert.cfg
	}
	echo "# https-listen" 1>&3

	[ "x$HTTP_PORT" != "x" ] && require-https
}

require-https () {
	(
		echo " server {"
		echo "	listen ${HTTP_PORT};"
		echo "	server_name "'~.*'";"
		echo '	rewrite ^ https://$host$request_uri? permanent;'
		echo "}"
	) 1>&3
}

###################################################


if [ -f /etc/squid3/squid-prefix.conf ]
then cat /etc/squid3/squid-prefix.conf /etc/squid3/squid.conf > "${SQUID_CONFIG_FILE}"
else cat /etc/squid3/squid.conf > "${SQUID_CONFIG_FILE}"
fi

cat /etc/squid3/squid.conf > "${SQUID_CONFIG_FILE}"

###################################################

( . /etc/reverse-proxy/reverse-proxy.conf ) 3> "${NGINX_CONFIG_FILE}" || die Creation of configuration file failed

###################################################

exec nginx -g "daemon off;"

