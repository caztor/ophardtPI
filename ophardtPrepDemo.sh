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
read -ps 'mySQL root password: ' dbpass

#Remove existing installation
#rm -f /var/www/student*

rm -f /etc/nginx/sites-available/student*
rm -f /etc/nginx/sites-enabled/student*

DB_STARTS_WITH="student"
MUSER="root"
MYSQL="mysql"

DBS="$($MYSQL -u$MUSER -p$dbpass -Bse 'show databases')"
for db in $DBS; do

if [[ "$db" =~ "^${DB_STARTS_WITH}" ]]; then
    echo "Deleting $db"
    $MYSQL -u$MUSER -p$dbpass -Bse "drop database $db"
fi

done

for (( demo=1; demo<=$democount; demo++ ))
do
	echo Preparing demo environment student$demo.$demodomain
	#cp -R /var/www/fencing /var/www/student$demo
	sed -i 's/score_fencing/student'$demo'/g' /var/www/student$demo/app/config/parameters.yml

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
	mysqldump -R -u root --password=$dbpass score_fencing | sudo myslq -u root --password=$dbpass student$demo

done

nginx -s reload
