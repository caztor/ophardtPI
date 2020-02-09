#!/bin/bash
#Make sure that Raspbian and packages are up to date
apt update
apt upgrade -y

#Install Apache, PHP, PHP Extensions, MariaDB, MySQL Python Connector, Java
apt install apache2 php7.2 mariadb-server php7.2-mysql php7.2-xml php7.2-curl php7.2-intl php7.2-zip php7.2-mbstring python-mysql.connector openjdk-8-jre ufw certbot python-certbot-apache -y

#Configure and Enable firewall
ufw allow 'OpenSSH'
ufw allow 'WWW Full'
ufw --force enable

#Change MySQL configuration
echo '[mysqld]
sql-mode=ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' >> /etc/mysql/conf.d/mysql.cnf
service mysqld restart

#Enable apache modules and sites
sudo a2enmod rewrite
sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite default-ssl
sudo a2enconf ssl-params

#Secure MySQL installation
mysql_secure_installation

#Download and install IonCube
wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_armv7l.tar.gz
tar -zxvf ioncube_loaders_lin_armv7l.tar.gz
cp ioncube/ioncube_loader_lin_7.2.so /usr/lib/php/20170718/
rm -r ioncube*
echo 'zend_extension = "/usr/lib/php/20170718/ioncube_loader_lin_7.2.so"' > /etc/php/7.2/apache2/conf.d/00-ioncube.ini

#Download and install Ophardt Linux Utilities
wget https://fencing.ophardt.online/software/20200101_3d46b7t/linux-utils.zip
unzip linux-utils.zip
mv linux-utils /var/www/
rm linux-utils.zip

#Create empty file in root, due to bug in ophardt-update.py for new installations
touch /root/bin

#Run Ophardt Update script to get the latest linux utils
python /var/www/linux-utils/updater/ophardt-update.py -s
