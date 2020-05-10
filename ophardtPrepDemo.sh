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
read -p 'Input domain suffix (i.e. example.com): ' demodomain

#Input root password for the mySQL database
read -sp 'Input root password for the mySQL database: ' dbpass

printf "\n\nRemoving old installation\n\n"

#Remove existing installation
echo - Cleaning up files
rm -Rf /var/www/student*

echo - Removing virtual host configurations
rm -f /etc/nginx/sites-available/student*
rm -f /etc/nginx/sites-enabled/student*

echo - Removing Databases
STMT=$(mysql -uroot -p$dbpass -Bse "SET SESSION group_concat_max_len = @@max_allowed_packet; SELECT GROUP_CONCAT(CONCAT('DROP DATABASE IF EXISTS ',SCHEMA_NAME,';') SEPARATOR ' ') FROM information_schema.SCHEMATA WHERE SCHEMA_NAME LIKE 'student_%';")
echo $STMT | mysql -uroot -p$dbpass

printf "\n\nBeginning installation\n\n"

for (( demo=1; demo<=$democount; demo++ ))
do
	echo Deploying environment student$demo.$demodomain
	echo - Copying files
	cp -R /var/www/fencing /var/www/student$demo
	echo - Setting permissions
	source ophardtUpdate.sh
	echo - Updating configuration
	sed -i 's/score_fencing/student'$demo'/g' /var/www/student$demo/app/config/parameters.yml

	echo - Creating virtual host configuration
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

	echo - Activating virtual host configuration
	ln -s /etc/nginx/sites-available/student$demo.$demodomain /etc/nginx/sites-enabled/student$demo.$demodomain
	
	echo - Creating DB and setting permissions
	echo "create database student$demo;" | mysql -u root --password=$dbpass
	echo "GRANT ALL PRIVILEGES ON student$demo.* TO 'scoring'@'localhost';" | mysql -u root --password=$dbpass
	mysqldump -R -u root --password=$dbpass score_fencing | mysql -u root --password=$dbpass student$demo

done

printf "\n\nReloading web server\n\n"
nginx -s reload
