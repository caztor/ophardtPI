#!/bin/bash
#Run this script to prepare a new demo environment or when you have updated the core software

#How many environments should we build
echo How many demo environments should we build?
read -p 'Input number (between 1-19): ' democount

#How many environments should we build
echo Where should the domain name be?
read -p 'Input domain suffix (i.e. example.com): ' demodomain

#Remove existing installation
#rm -f /var/www/student*

rm -f /etc/nginx/sites-available/student*
rm -f /etc/nginx/sites-enabled/student*

for demo in {1..$democount}
do
	echo Preparing demo environment student$demo.$demodomain
	#cp -R /var/www/fencing /var/www/student$demo
	sed -i 's/score_fencing/student$demo/g' /var/www/student$demo/app/config/parameters.yml

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

	sudo ln -s /etc/nginx/sites-available/student$demo.$demodomain /etc/nginx/sites-enabled/student$demo.$demodomain

done
