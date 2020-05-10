#!/bin/bash
#Run this script to prepare a new demo environment or when you have updated the core software

if [ "$EUID" -ne 0 ]
  then echo "Please run as root (sudo)"
  exit
fi

HOSTSUFFIX="student"

#How many environments should we build
while true
do
echo How many demo environments should we build?
read -p 'Input number (between 1-19): ' ENVCOUNT
    if [ $ENVCOUNT ] && [ $ENVCOUNT -gt 0 ] && [ $ENVCOUNT -lt 20 ] ;
    then
	 break
     else
         echo "You need to enter a valid value!"
     fi
done

#Get the domain suffix
read -p 'Input domain suffix (i.e. example.com): ' DOMAIN

#Input root password for the mySQL database
read -sp 'Input root password for the mySQL database: ' DBPASS

printf "\n\nRemoving old installation\n\n"

#Remove existing installation
echo - Cleaning up files
rm -Rf /var/www/$HOSTSUFFIX*

echo - Removing virtual host configurations
rm -f /etc/nginx/sites-available/$HOSTSUFFIX*
rm -f /etc/nginx/sites-enabled/$HOSTSUFFIX*

echo - Removing Databases
DBDROP=$(mysql -uroot -p$DBPASS -Bse "SET SESSION group_concat_max_len = @@max_allowed_packet; SELECT GROUP_CONCAT(CONCAT('DROP DATABASE IF EXISTS ',SCHEMA_NAME,';') SEPARATOR ' ') FROM information_schema.SCHEMATA WHERE SCHEMA_NAME LIKE 'student_%';")
echo $DBDROP | mysql -uroot -p$DBPASS

printf "\n\nBeginning installation\n\n"

for (( i=1; i<=$ENVCOUNT; i++ ))
do
	HOSTNAME=$HOSTSUFFIX$i
	echo Deploying environment $HOSTNAME.$DOMAIN

	echo - Copying files
	cp -R /var/www/fencing /var/www/$HOSTNAME

	echo - Setting permissions
	chown -R www-data:www-data /var/www/$HOSTNAME/*
	chmod -R 0744 /var/www/$HOSTNAME/*
	chmod 0755 -R /var/www/$HOSTNAME/OphardtSync/
	chmod 0440 /var/www/$HOSTNAME/app/config/ophardt_license.yml

	echo - Updating configuration
	sed -i 's/score_fencing/'$HOSTNAME'/g' /var/www/$HOSTNAME/app/config/parameters.yml

	echo - Creating virtual host configuration
	cat > /etc/nginx/sites-available/$HOSTNAME.$DOMAIN << EOF
# Virtual Host configuration for $HOSTNAME.$DOMAIN

server {
	listen 80;
	listen [::]:80;

	server_name $HOSTNAME.$DOMAIN;

	root /var/www/$HOSTNAME/web;
	index app.php;

	location / {
		try_files \$uri \$uri/ /app.php?a=\$uri;
	}
        # pass PHP scripts to FastCGI server
        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
        #       # With php-fpm (or other unix sockets):
                fastcgi_pass unix:/run/php/php7.2-fpm.sock;
        }

        # deny access to .htaccess files, if Apache's document root concurs with nginx's one
        location ~ /\.ht {
                deny all;
        }
}
EOF

	echo - Activating virtual host configuration
	ln -s /etc/nginx/sites-available/$HOSTNAME.$DOMAIN /etc/nginx/sites-enabled/$HOSTNAME.$DOMAIN
	
	echo - Creating DB and setting permissions
	echo "create database $HOSTNAME;" | mysql -uroot -p$DBPASS
	echo "GRANT ALL PRIVILEGES ON $HOSTNAME.* TO 'scoring'@'localhost';" | mysql -u root -p$DBPASS
	mysqldump -R -uroot -p$DBPASS score_fencing | mysql -uroot -p$DBPASS $HOSTNAME

done

printf "\n\nReloading web server\n\n"
nginx -s reload
