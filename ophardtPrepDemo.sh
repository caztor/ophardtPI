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
rm -f /etc/ssl/certs/$HOSTNAME*
rm -f /etc/ssl/private/$HOSTNAME*

echo - Removing Databases
DBDROP=$(mysql -uroot -p$DBPASS -Bse "SET SESSION group_concat_max_len = @@max_allowed_packet; SELECT GROUP_CONCAT(CONCAT('DROP DATABASE IF EXISTS ',SCHEMA_NAME,';') SEPARATOR ' ') FROM information_schema.SCHEMATA WHERE SCHEMA_NAME LIKE 'student_%';")
if [ ! -z "$DBDROP" ] ; then echo $DBDROP | mysql -uroot -p$DBPASS; fi

printf "\n\nBeginning installation\n\n"

if [ ! -f '/etc/ssl/certs/dhparam.pem' ] ; then openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048; fi

for (( i=1; i<=$ENVCOUNT; i++ ))
do
	HOSTNAME=$HOSTSUFFIX$i
	echo Deploying environment $HOSTNAME.$DOMAIN

	echo - Copying files
	cp -R /var/www/fencing /var/www/$HOSTNAME
	wget -q -O /var/www/$HOSTNAME/web/img/logo.png https://raw.githubusercontent.com/caztor/ophardtPI/master/logo/logo$i.png 

	echo - Setting permissions
	chown -R www-data:www-data /var/www/$HOSTNAME/*
	chmod -R 0744 /var/www/$HOSTNAME/*
	chmod 0755 -R /var/www/$HOSTNAME/OphardtSync/
	chmod 0440 /var/www/$HOSTNAME/app/config/ophardt_license.yml

	echo - Updating configuration
	sed -i 's/score_fencing/'$HOSTNAME'/g' /var/www/$HOSTNAME/app/config/parameters.yml

	echo - Generating certificates
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/$HOSTNAME.$DOMAIN.key -out /etc/ssl/certs/$HOSTNAME.$DOMAIN.crt -subj "/C=DK/ST=DK/L=Copenhagen/O=Ophardt Touch Demo/OU=IT/CN=$HOSTNAME.$DOMAIN"

	echo - Creating virtual host configuration
	cat > /etc/nginx/sites-available/$HOSTNAME.$DOMAIN << EOF
# Virtual Host configuration for $HOSTNAME.$DOMAIN

server {
	listen 443 http2 ssl;
	listen [::]:443 http2 sll;

	server_name $HOSTNAME.$DOMAIN;

	root /var/www/$HOSTNAME/web;
	index app.php;

	ssl_certificate /etc/ssl/certs/$HOSTNAME.$DOMAIN.crt;
        ssl_certificate_key /etc/ssl/private/$HOSTNAME.$DOMAIN.key;
	ssl_dhparam /etc/ssl/certs/dhparam.pem;

	########################################################################
	# from https://cipherli.st/                                            #
	# and https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html #
	########################################################################

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_prefer_server_ciphers on;
	ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
	ssl_ecdh_curve secp384r1;
	ssl_session_cache shared:SSL:10m;
	ssl_session_tickets off;
	ssl_stapling on;
	ssl_stapling_verify on;
	resolver 8.8.8.8 8.8.4.4 valid=300s;
	resolver_timeout 5s;
	# Disable preloading HSTS for now.  You can use the commented out header line that includes
	# the "preload" directive if you understand the implications.
	#add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
	add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
	add_header X-Frame-Options DENY;
	add_header X-Content-Type-Options nosniff;

	##################################
	# END https://cipherli.st/ BLOCK #
	##################################

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
