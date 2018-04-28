#!/bin/bash

#Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

VERSION="master"
if [[ $1 != "" ]]; then VERSION=$1; fi

echo "WIZnet LoRa Gateway installer"
echo "Version $VERSION"

# Update the gateway installer to the correct branch (defaults to master)
echo "Updating installer files..."
OLD_HEAD=$(git rev-parse HEAD)
git fetch
git checkout -q $VERSION
git pull
NEW_HEAD=$(git rev-parse HEAD)

if [[ $OLD_HEAD != $NEW_HEAD ]]; then
	echo "New installer found. Restarting process..."
	exec "./install.sh" "$VERSION"
fi

# Request gateway configuration data
# There are two ways to do it, manually specify everything
# or rely on the gateway EUI and retrieve settings files from remote (recommended)
echo "Gateway configuration:"

# Try to get gateway ID from MAC address
# First try eth0, if that does not exist, try wlan0 (for RPi Zero)
GATEWAY_EUI_NIC="eth0"
if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
	GATEWAY_EUI_NIC="wlan0"
fi

if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
	echo "ERROR: No network interface found. Cannot set gateway ID."
	exit 1
fi
#
GATEWAY_EUI=$(ip link show $GATEWAY_EUI_NIC | awk '/ether/ {print $2}' | awk -F\: '{print $1$2$3"FFFE"$4$5$6}')
GATEWAY_EUI=${GATEWAY_EUI^^} # toupper


# Install LoRaWAN packet forwarder repositories
INSTALL_DIR="/opt/lora-gateway"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi
pushd $INSTALL_DIR


# Build LoRa Gateway app
if [ ! -d lora_gateway ]; then
	git clone -b master https://github.com/Lora-net/lora_gateway.git
	pushd lora_gateway
else
	pushd lora_gateway
	git fetch origin
	git checkout master
	git reset --hard
fi

make

popd

# Build packet forwarder
if [ ! -d packet_forwarder ]; then
	git clone -b master https://github.com/Lora-net/packet_forwarder.git
	pushd packet_forwarder
else
	pushd packet_forwarder
	git fetch origin
	git checkout master
	git reset --hard
fi

make

popd

# Symlink packet forwarder

if [ ! -d bin ]; then mkdir bin; fi
if [ -f ./bin/lora_pkt_fwd ]; then rm ./bin/lora_pkt_fwd; fi
ln -s $INSTALL_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd ./bin/lora_pkt_fwd
cp -f ./packet_forwarder/lora_pkt_fwd/global_conf.json ./bin/global_conf.json

LOCAL_CONFIG_FILE=$INSTALL_DIR/bin/local_conf.json



#Remove old config file
if [ -e $LOCAL_CONFIG_FILE ]; then rm $LOCAL_CONFIG_FILE; fi;

if [ "$REMOTE_CONFIG" = true ] ; then
	# Get remote configuration repo
	if [ ! -d gateway-remote-config ]; then
		git clone https://github.com/ttn-zh/gateway-remote-config.git
		pushd gateway-remote-config
	else
	    pushd gateway-remote-config
	    git pull
	    git reset --hard
	fi
	
	ln -s $INSTALL_DIR/gateway-remote-config/$GATEWAY_EUI.json $LOCAL_CONFIG_FILE

	popd
else
echo -e "{\n\t\"gateway_conf\": {\n\t\t\"gateway_ID\": \"$GATEWAY_EUI\",\n\t\t\"server_address\": \"222.98.173.208\", \n\t\"serv_port_up\": 1680, \n\t\"serv_port_down\": 1680, \n\t}\n}" >$LOCAL_CONFIG_FILE
fi

popd

echo "Gateway EUI is: $GATEWAY_EUI"
echo "The hostname is: $NEW_HOSTNAME"
#echo "Open TTN console and register your gateway using your EUI: https://console.thethingsnetwork.org/gateways"
echo
echo "Installation completed."

# Start packet forwarder as a service
cp ./start.sh $INSTALL_DIR/bin/
cp ./lora-gateway.service /lib/systemd/system/
systemctl enable lora-gateway.service

echo "The system will reboot in 5 seconds..."
sleep 5
shutdown -r now


