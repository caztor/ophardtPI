#!/bin/bash
#Run this script to prepare a new demo environment or when you have updated the core software

if [ "$EUID" -ne 0 ]
  then echo "Please run as root (sudo)"
  exit
fi

#How many environments should we build
echo How many demo environments should we build?
read -p 'Input number (between 1-19): ' democount

#How many environments should we build
echo Where should the domain name be?
read -p 'Input domain suffix (i.e. example.com): ' demodomain

#Input root password for the mySQL database
echo Input root password for the mySQL database
read -sp 'mySQL root password: ' dbpass

#Remove existing installation
#rm -f /var/www/student*

rm -f /etc/nginx/sites-available/student*
rm -f /etc/nginx/sites-enabled/student*

STMT=$(mysql -uroot -p$dbpass -Bse "SET SESSION group_concat_max_len = @@max_allowed_packet; SELECT GROUP_CONCAT(CONCAT('DROP DATABASE IF EXISTS ',SCHEMA_NAME,';') SEPARATOR ' ') FROM information_schema.SCHEMATA WHERE SCHEMA_NAME LIKE 'student_%';")
echo $STMT | mysql -uroot -p$dbpass

for (( demo=1; demo<=$democount; demo++ ))
do
	echo Preparing demo environment student$demo.$demodomain
	#cp -R /var/www/fencing /var/www/student$demo
	#source ophardtUpdate.sh
	#sed -i 's/score_fencing/student'$demo'/g' /var/www/student$demo/app/config/parameters.yml

	cat > /etc/nginx/sites-available/student$demo.$demodomain << EOF
# Virtual Host configuration for student$demo.$demodomain

server {
	listen 80;
	listen [::]:80;

	server_name student$demo.$demodomain;

	root /var/www/student$demo;
	index app.php;

	location / {
		try_files $uri $uri/ /app.php?a=$uri;
	}
}
EOF

	ln -s /etc/nginx/sites-available/student$demo.$demodomain /etc/nginx/sites-enabled/student$demo.$demodomain
	echo - Creating DB
	echo "create database student$demo;" | mysql -u root --password=$dbpass
	mysqldump -R -u root --password=$dbpass score_fencing | mysql -u root --password=$dbpass student$demo

done

nginx -s reload
