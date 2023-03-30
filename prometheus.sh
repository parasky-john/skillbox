#!/bin/bash
set -x
#Error logging
exec 2> error_log

dir=/tmp/
deb=prometheus_0.1-1_all.deb
go_distr=$dir"go1.15.2.linux-amd64.tar.gz"
ovpexp=$dir"v0.3.0.tar.gz"

#Add GO PATH
export PATH=$PATH:$HOME/bin:/usr/local/go/bin

#Function check packet
distr(){
#проверяем состояние пакета (dpkg) и ищем в выводе его статус (grep)
I=`dpkg -s $1 | grep "Status: install ok installed" `
#проверяем что нашли строку со статусом установки Easy RSA (что строка не пуста)
if [ "$I" ] 
then
   echo "$1 is alredy install"
else
   echo "$1 now installing..."
   sudo apt-get install $1
fi;
}

#Установка прометеуса, алерменеджера и нод-экспортера"
distr "prometheus"
distr "prometheus-node-exporter"
distr "prometheus-alertmanager"

#Приносим пакетом необходимые дистрибутивы и конф. файлы"
sudo dpkg -i $dir$deb

#Install the GO environment
if test -f $go_distr
	then
		if test -d "/usr/local/go"
			then
			echo "GO is already installed"
			else
			tar -C /usr/local -xzf $go_distr
			sudo echo "PATH=$PATH:$HOME/bin:/usr/local/go/bin" >> /etc/profile
		fi;
	else
	echo "No file " $go_distr 
	exit 1
fi;

#Install OpenVPN_EXPORTER
cd $dir
if test -f $ovpexp
	then
	tar xzf $ovpexp
	else
	echo "No file " $ovpexp
	exit 1
fi;

#copy file main.go with right configuration
if test -d $dir"openvpn_exporter-0.3.0/"
	then
	cp $dir"main.go" $dir"openvpn_exporter-0.3.0/"
	else
	echo "No such directory openvpn_exporter-0.3.0, something wrong with unpacking " $ovpexp
	exit 1
fi;


#Compile into OpenVPN_EXPORTER
sudo mkdir -p /opt/tools
cd $dir"openvpn_exporter-0.3.0/" 
go build -o openvpn_exporter main.go
sudo cp $dir"openvpn_exporter-0.3.0/openvpn_exporter" /usr/local/bin

#copy prometheus conf
sudo cp /tmp/prometheus.yml /etc/prometheus/
sudo cp /tmp/myrules.yml /etc/prometheus/

#copy alertmanager conf file
sudo cp /tmp/alertmanager.yml /etc/prometheus/


#openvpn-exporter systemd start
sudo cp /tmp/openvpn_exporter.service /etc/systemd/system/

 # Refresh the configuration file
sudo systemctl daemon-reload
 #     and set the boot from the boot
sudo systemctl enable --now openvpn_exporter.service
sudo systemctl restart prometheus
sudo systemctl restart prometheus-alertmanager
sudo systemctl restart prometheus-node-exporter
 # View status
sudo systemctl status prometheus | grep Active
sudo systemctl status prometheus-alertmanager | grep Active
sudo systemctl status prometheus-node-exporter | grep Active
sudo systemctl status openvpn_exporter | grep Active