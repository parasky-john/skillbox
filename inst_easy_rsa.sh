#!/bin/bash
#set -x
#Конфигурационные переменные
dir=/usr/share/easy-rsa/
path_dep=/tmp/rsa_0.1-1_all.deb

#проверяем состояние пакета (dpkg) и ищем в выводе его статус (grep)
I=`dpkg -s easy-rsa | grep "Status" ` 

#Проверяем успешность выполнения apt-get update
if ! sudo apt-get update
	then
		echo "Something wrong with Apt update"
		exit 1
fi;

#проверяем что нашли строку со статусом установки Easy RSA (что строка не пуста)
if [ -n "$I" ] 
then
   echo "Easy RSA is alredy install"
else
   echo "Easy RSA now installing..."
   sudo apt-get install easy-rsa
fi;

#Проверка наличия необходимой папки для дальнейшей работы
if test ! -d $dir
	then
		sudo mkdir $dir -p
fi;

cd $dir
./easyrsa init-pki

#Пакет приносит файл vars
if test -f $path_dep;
        then
                sudo dpkg -i $path_dep
        else
                echo "No such file: "$path_dep
                exit 1
fi;

if test -f $dir"vars"
	then
	./easyrsa build-ca
	else
	echo "No file vars in "$dir 
	exit 1
fi;
