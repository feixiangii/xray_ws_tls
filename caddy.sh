#!/bin/bash
# FILE="/etc/Caddy"
domain="$1"
psname="$2"
uuid="51be9a06-299f-43b9-b713-1ec5eb76e3d7"
path="3o38nn5h"
aid="64"

if  [ ! "$3" ] ;then
    uuid=$(uuidgen)
    echo "uuid 将会随机生成为${uuid}"
else
    uuid="$3"
fi

if  [ ! "$4" ] ;then
    path=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
    echo "ws path 将会随机生成为${path}"
else
    path="$4"
fi

if  [ ! "$5" ] ;then
    aid=$(shuf -i 30-100 -n 1)
    echo "alertId 将会随机生成为${aid}"
else
    aid="$5"
fi

cat > /etc/Caddyfile <<'EOF'
{
	order reverse_proxy before header
}
domain {
	log {
		output file ./caddy.log {
		  roll_size 10mb
		  roll_keep 30
		  roll_keep_for 72h
		}
		level  WARN
	}
	tls {
		ciphers TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
        alpn h2 http/1.1
    	on_demand
	}
	@v2ray_ws {
        path /onepath
        header Connection *Upgrade*
        header Upgrade websocket
    }
	reverse_proxy @v2ray_ws 127.0.0.1:2333
	@blocked {
		path *.js *.log *.json /node_modules/*
	}
	respond @blocked 404
	file_server
	header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }
}
EOF

sed -i "s/domain/${domain}/" /etc/Caddyfile
sed -i "s/onepath/${path}/" /etc/Caddyfile

# v2ray
cat > /etc/v2ray/config.json <<'EOF'
{
	"log": {
		"loglevel": "warning",
		"error": "/srv/v2ray_error.log",
		"access": "/srv/v2ray_access.log"
	},
	"inbounds": [{
		"listen": "127.0.0.1",
		"port": 2333,
		"protocol": "vmess",
		"settings": {
			"clients": [{
				"id": "uuid",
				"alterId": 64
			}],
			"disableInsecureEncryption": true
		},
		"streamSettings": {
			"network": "ws",
			"security": "none",
			"wsSettings": {
			"path": "/onepath"
			}
		},
		"sniffing": {
			"enabled": false,
			"destOverride": [
			  "http",
			  "tls"
        ]}
    }],
	"routing": {
		"domainStrategy": "IPIfNonMatch",
		"rules": [{
			"type": "field",
			"protocol": [
				"bittorrent"
			],
        "outboundTag": "blocked"
		}]
	},
	"outbounds": [{
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }]
}
EOF

sed -i "s/uuid/${uuid}/" /etc/v2ray/config.json
sed -i "s/onepath/${path}/" /etc/v2ray/config.json
sed -i "s/64/${aid}/" /etc/v2ray/config.json

#https://github.com/2dust/v2rayN/wiki/分享链接格式说明(ver-2)
cat > /srv/sebs.js <<'EOF'
{
	"add":"domain",
    "aid":"64",
    "host":"domain",
    "id":"uuid",
    "net":"ws",
    "path":"/onepath",
    "port":"443",
    "ps":"sebsclub",
    "tls":"tls",
    "type":"none",
    "v":"2"
}
EOF

if [ "$psname" != "" ] && [ "$psname" != "-c" ]; then
  sed -i "s/sebsclub/${psname}/" /srv/sebs.js
  sed -i "s/domain/${domain}/" /srv/sebs.js
  sed -i "s/uuid/${uuid}/" /srv/sebs.js
  sed -i "s/onepath/${path}/" /srv/sebs.js
  sed -i "s/64/${aid}/" /srv/sebs.js
else
  $*
fi
pwd
cp /etc/Caddyfile .
nohup /bin/parent caddy run --environ &
echo "配置 JSON 详情"
echo " "
cat /etc/v2ray/config.json
echo " "
node v2ray.js
/usr/bin/v2ray -config /etc/v2ray/config.json
