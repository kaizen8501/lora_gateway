#!/bin/bash

#Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi


if [[ 'grep "loraserver" /opt/lora-gateway/bin' != "" ]]; then
    systemctl stop loraserver
    rm /opt/lora-gateway/bin/loraserver
fi

if [[ 'grep "lora-app-server" /opt/lora-gateway/bin' != "" ]]; then
    systemctl stop lora-app-server
    rm /opt/lora-gateway/bin/lora-app-server
fi

if [[ 'grep "lora-gateway-bridge" /opt/lora-gateway/bin' != "" ]]; then
    systemctl stop lora-gateway-bridge 
    rm /opt/lora-gateway/bin/lora-gateway-bridge
fi

cp ./loraserver /opt/lora-gateway/bin
cp ./loraserver.toml /opt/lora-gateway/bin

cp ./lora-app-server /opt/lora-gateway/bin
cp ./lora-app-server.toml /opt/lora-gateway/bin

cp ./lora-gateway-bridge /opt/lora-gateway/bin
cp ./lora-gateway-bridge.toml /opt/lora-gateway/bin

cp ./server.* /opt/lora-gateway/bin

cp ./*.service /lib/systemd/system
systemctl enable lora-gateway-bridge.service
systemctl enable loraserver.service
systemctl enable lora-app-server.service

