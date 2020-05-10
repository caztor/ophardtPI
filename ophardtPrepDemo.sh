#!/bin/bash
#Run this script to prepare a new demo environment or when you have updated the core software

#How many environments should we build
echo How many demo environments should we build?
read -p 'Input number (between 1-19): ' democount

#How many environments should we build
echo Where should the domain name be?
read -p 'Input domain suffix (i.e. example.com): ' demodomain

#Remove existing installation
#rm /var/www/student*

cat > /etc/nginx/sites-available/student1.$demodomain << EOF
# Virtual Host configuration for $demodomain

server {
	listen 80;
	listen [::]:80;

	server_name student1.$demodomain;

	root /var/www/student1;
	index app.php;

	location / {
		try_files $uri $uri/ /app.php?a=$uri;
	}
}
EOF
