#!/bin/bash

#Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

#Install mosquitto mqtt broker
echo "Install Mosquitto MQTT Broker"
apt-get --purge remove mosquitto
apt-get install mosquitto

#Install Postresql
echo "Install Postgresql"
apt-get --purge remove postgresql
apt-get install postgresql-9.6
systemctl enable postgresql

#Install Redis database
echo "Install Redis Database"
apt-get --purge remove redis-server
apt-get install redis-server

#Create an user and database for lora-server
DBPASSWORD=dbpassword

sudo -u postgres psql << EOF 
    create role loraserver_ns with login password '$DBPASSWORD';
    create database loraserver_ns with owner loraserver_ns;
EOF


#Create an user and database for lora-app-server
sudo -u postgres psql << EOF
    create role loraserver_as with login password '$DBPASSWORD';
    create database loraserver_as with owner loraserver_as;
    \c loraserver_as
    create extension pg_trgm;
EOF
