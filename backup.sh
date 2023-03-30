#!/bin/bash
#Задаем текущую дату
date=$(date +%F)
#Функция проверки наличия папки 
dir(){
if test ! -d $1
then
mkdir $1
fi;
}

dir "/tmp/backup"
dir "/tmp/backup/server"
dir "/tmp/backup/client"

#Копируем необходимые файлы
cp -b /usr/share/easy-rsa/pki/private/ca.key /tmp/backup
cp -b /usr/share/easy-rsa/pki/ca.crt /tmp/backup
cp -b /etc/openvpn/server/{server.crt,server.key,ta.key} /tmp/backup/server
cp -br /etc/openvpn/client/files /tmp/backup/client
cp -br /etc/openvpn/client/keys /tmp/backup/client

#Пакуем в архив
tar -zcvf /tmp/backup.tar.gz_$date /tmp/backup

#Проверяем наличие архива и удаляем папку
if test -f /tmp/backup.tar.gz_$date
then
rm -rd /tmp/backup
echo "your backup is /tmp/backup.tar.gz_"$date
else
echo "something wrong with packing"
exit 1
fi;