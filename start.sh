#!/bin/bash

VHOSTNUMBER=0
#set -x

export PROXY_CLIENT_CA=${PROXY_CLIENT_CA-/etc/ssl/certs/proxy-client-ca.pem}


update-ca-certificates
	
export SSL_CIPHER="ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK"

export HOST_SSL_CERT=${HOST_SSL_CERT-/etc/ssl/certs/host.crt.pem}
export HOST_SSL_KEY=${HOST_SSL_KEY-/etc/ssl/private/host.key.pem}
export HTTPS_PORT=
export HTTP_PORT=

export INDEX_PAGE_ROOT=/var/run/reverse-proxy-htdocs
export INDEX_PAGE_PATH=

NGINX_CONFIG_FILE=/etc/nginx/conf.d/default.conf

export REQUIRE_CLIENT_CA=

require-client-ca() {
	export REQUIRE_CLIENT_CA=1
}

no-require-client-ca() {
	export REQUIRE_CLIENT_CA=
}

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
        echo "	ssl_session_timeout  120m;"
        #echo "	ssl_protocols        SSLv3 TLSv1;"
        echo "	ssl_ciphers          $SSL_CIPHER;"
        echo "	ssl_prefer_server_ciphers   on;"
		echo "  ssl_verify_depth 2;"
		
		[ -f "${PROXY_CLIENT_CA}" ] && [ "${REQUIRE_CLIENT_CA}" = "1" ] && {
			echo "  ssl_client_certificate ${PROXY_CLIENT_CA};"
			#echo "  ssl_trusted_certificate ${PROXY_CLIENT_CA};"
			echo "  ssl_verify_client on;"
		}
	else
		echo "	listen $HTTP_PORT;"
	fi

	echo "client_max_body_size 300M;"

	echo "proxy_buffering off;"
	#echo "proxy_buffer_size 4k;"
}


add-static-vhost () {
	local root_path=$1
	local server_name=$2
	shift
	shift

	[ "${INDEX_PAGE_PATH}" != "" ] && {
		(
			echo '<br /><a href="https://'$server_name'">'$server_name'</a>'
		) >> "${INDEX_PAGE_PATH}"
	}

	(
		echo "server {"
		add-server-port-stuff
		echo "	server_name $server_name;"
		echo "	location / {"
		echo "      root $root_path;"
		echo "	}"
		echo "}"
	) 1>&3
}

add-vhost-index () {
	local server_name=$1
	shift

	[ "${server_name}" = "" ] && return

	export INDEX_PAGE_PATH="$INDEX_PAGE_ROOT/index.html"
	mkdir -p "$INDEX_PAGE_ROOT"
	add-static-vhost "$INDEX_PAGE_ROOT" "${server_name}"
	rm -f "$INDEX_PAGE_PATH"
	touch "$INDEX_PAGE_PATH"
}

_echo-location-info () {
	local proxy_pass="$1"
	echo "	location / {"
	echo "		proxy_pass ${proxy_pass}/;"
	echo "		proxy_http_version 1.1;"
	echo '		proxy_redirect off;'
	echo '		proxy_set_header X-Real-IP $remote_addr;'
	echo '		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;'
	echo '		proxy_set_header X-NginX-Proxy true;'
	echo '		proxy_set_header Host $http_host;'
	echo '		proxy_set_header Upgrade $http_upgrade;'
	echo '		proxy_set_header Connection $connection_upgrade;'
	echo "	}"

	echo "	location /api/websocket/ {"
	echo "		proxy_pass ${proxy_pass}/api/websocket/;"
	echo "		proxy_http_version 1.1;"
	echo '      proxy_set_header Upgrade $http_upgrade;'
	echo '		proxy_set_header X-Real-IP $remote_addr;'
	echo '		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;'
	echo '		proxy_set_header X-NginX-Proxy true;'
	#echo '		proxy_set_header Host $http_host;'
	echo '		proxy_set_header Upgrade $http_upgrade;'
	#echo '		proxy_set_header Connection $connection_upgrade;'
	echo '      proxy_set_header Connection "upgrade";'
	echo "	}"

}

add-http-vhost () {
	local address=$1
	local port=$2
	shift
	shift
	local server_name=$*
	
	[ "${INDEX_PAGE_PATH}" != "" ] && {
		(
			echo '<br /><a href="https://'$server_name'">'$server_name'</a>'
		) >> "${INDEX_PAGE_PATH}"
	}

	(
		echo "server {"
		add-server-port-stuff
		echo "	large_client_header_buffers 8 32k;"
		echo "	server_name $server_name;"
		_echo-location-info "http://$address:$port"
		echo "}"
	) 1>&3
}

add-https-vhost () {
	local name=vhost-$((VHOSTNUMBER++))
	local address=$1
	local port=$2
	shift
	shift
	local server_name=$*

	[ "${INDEX_PAGE_PATH}" != "" ] && {
		(
			echo '<br /><a href="https://'$server_name'">'$server_name'</a>'
		) >> "${INDEX_PAGE_PATH}"
	}

	
	(
		echo "server {"
		add-server-port-stuff
		echo "	large_client_header_buffers 8 32k;"
		echo "	server_name $*;"
		_echo-location-info "https://$address:$port"
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

enable-websockets () {
	(
		echo ' map $http_upgrade $connection_upgrade {'
		echo "	default Upgrade;"
		#echo "	''      close;"
		echo "	''      '';"
		echo "}"
	) 1>&3
}

###################################################

(
	enable-websockets

	. /etc/reverse-proxy/reverse-proxy.conf
) 3> "${NGINX_CONFIG_FILE}" || die Creation of configuration file failed

###################################################

exec nginx -g "daemon off;"

