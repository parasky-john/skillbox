#!/bin/bash
#set -x

#Конфигурационные переменные
path_dep=/tmp/vpn-cl-conf_0.1-1_all.deb
dir_rsa=/usr/share/easy-rsa/
dir_vpn_server=/etc/openvpn/server/
KEY_DIR=/etc/openvpn/client/keys
OUTPUT_DIR=/etc/openvpn/client/files
BASE_CONFIG=/etc/openvpn/client/base.conf

#Процедура создания клиентского сертификата
cd $dir_rsa
read -p "Enter name of client: " client
./easyrsa gen-req $client nopass
if test ! -d $KEY_DIR;
	then
		sudo mkdir -p $KEY_DIR
		echo "please restart this script"
		exit 1
fi;
mv pki/private/$client.key $KEY_DIR
./easyrsa import-req pki/reqs/$client.req $client
./easyrsa sign-req client $client
cp pki/issued/$client.crt $KEY_DIR

#Конфигурация клиента VPN
if test ! -d $OUTPUT_DIR;
	then
		sudo mkdir -p $OUTPUT_DIR
		echo "please restart this script"
		exit 1
fi;

#Создание *.ovpn клиентского файла
if test -f $BASE_CONFIG;
	then
	
cat ${BASE_CONFIG} \
	    <(echo -e '<ca>') \
	        ${KEY_DIR}/ca.crt \
		    <(echo -e '</ca>\n<cert>') \
		        ${KEY_DIR}/$client.crt \
			    <(echo -e '</cert>\n<key>') \
			        ${KEY_DIR}/$client.key \
				    <(echo -e '</key>\n<tls-crypt>') \
				        ${KEY_DIR}/ta.key \
					    <(echo -e '</tls-crypt>') \
					        > ${OUTPUT_DIR}/$client.ovpn
	else
	echo "No file base.conf in "$BASE_CONFIG
	exit 1
fi;

#Проверка наличия конечного *.ovpn файла
if test -f $OUTPUT_DIR/$client.ovpn;
        then
                echo "*.ovpn file to client: "$OUTPUT_DIR/$client.ovpn
        else
                "Something wrong with " $OUTPUT_DIR/$client.ovpn
                exit 1
fi;
