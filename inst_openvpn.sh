#!/bin/bash
#set -x

#Конфигурационные переменные
path_dep=/tmp/vpn-cl-conf_0.1-1_all.deb
dir_rsa=/usr/share/easy-rsa/
dir_vpn_server=/etc/openvpn/server/
dir_cl=/etc/openvpn/client/
KEY_DIR=/etc/openvpn/client/keys
OUTPUT_DIR=/etc/openvpn/client/files
BASE_CONFIG=/etc/openvpn/client/base.conf

#запись в переменную имени сетевого интерфейса
eth=`ip route list default | awk '{print $5}'` 

#проверяем состояние пакета (iptables) и ищем в выводе его статус (grep)
I_tables=`dpkg -s iptables | grep "Status" `
 
#проверяем состояние пакета (openvpn) и ищем в выводе его статус (grep)
I=`dpkg -s openvpn | grep "Status" ` 

#проверяем что нашли строку со статусом установки iptables (что строка не пуста)
if [ -n "$I_tables" ] 
then
   echo "Iptables is alredy install" 
else
   echo "Iptables now installing..."
   sudo apt-get install iptables
fi;

#Проверяем успешность выполнения apt-get update
if ! sudo apt-get update
        then
                echo "Something wrong with Apt-get update"
                exit 1
fi;

#проверяем что нашли строку со статусом установки OpenVPN (что строка не пуста)
if [ -n "$I" ] 
then
   echo "OpenVPN is alredy install"
else
   echo "OpenVPN now installing..."
   sudo apt-get install openvpn
fi;

#Процедура создания сертификата сервера
cd $dir_rsa
./easyrsa gen-req server nopass
if test -d $dir_vpn_server
	then
		sudo mv $dir_rsa/pki/private/server.key $dir_vpn_server
	else
	echo "Making... "$dir_vpn_server
	sudo mkdir -p $dir_vpn_server
	echo "Please, restart script"
	exit 1
fi;

./easyrsa import-req pki/reqs/server.req server
./easyrsa sign-req server server
if test -f $dir_rsa/pki/ca.crt
	then
		sudo cp $dir_rsa/pki/ca.crt $dir_vpn_server
	else
		echo "No file "$dir_rsa"/pki/ca.crt"
		exit 1
fi;
if test -f $dir_rsa/pki/issued/server.crt
	then
		sudo cp $dir_rsa/pki/issued/server.crt $dir_vpn_server
	else
		echo "No file "$dir_rsa"/pki/issued/server.crt"
		exit 1
fi;

#Генерация ta ключа
openvpn --genkey --secret ta.key
if test -f ta.key
	then
		sudo cp ta.key $dir_vpn_server
	else
		echo "No file ta.key"
		exit 1
fi;

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
cp pki/private/$client.key $KEY_DIR
./easyrsa import-req pki/reqs/$client.req $client
./easyrsa sign-req client $client
cp pki/issued/$client.crt $KEY_DIR
cp $dir_rsa/ta.key $KEY_DIR
sudo cp $dir_vpn_server"ca.crt" $KEY_DIR

#Конфигурация клиента VPN
if test ! -d $OUTPUT_DIR;
	then
		sudo mkdir -p $OUTPUT_DIR
		echo "please restart this script"
		exit 1
fi;

#Пакет приносит base.conf и server.conf 
if test -f $path_dep;
        then
                sudo dpkg -i $path_dep
        else
                echo "No such file: "$path_dep
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
		 
#Производим настройку проходов iptables для корректной работы VPN 
sudo iptables -F
iptables -A INPUT -i "$eth" -m state --state NEW -p udp --dport 1194 -j ACCEPT
# Allow TUN interface connections to OpenVPN server
iptables -A INPUT -i tun+ -j ACCEPT
# Allow TUN interface connetcions to be forwarded through other interface
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -o "$eth" -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i "$eth" -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
# NAT the VPN client traffic to the internet
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$eth" -j MASQUERADE

#Сохраняем iptables на случай перезагрузкин\выключения\сбоя
sudo iptables-save > /etc/iptables/rules.v4
sudo service netfilter-persistent save

#Стартуем VPN Сервер
sudo systemctl -f enable openvpn-server@server.service
sudo systemctl start openvpn-server@server.service
