#!/bin/bash
echo 'This will install Ophardt on your Raspberry Pi 4B'

PS3='Please choose desired webserver: '
options=("Apache2" "Nginx" "Quit")
select SERVER in "${options[@]}"
do
    case $SERVER in
        "Apache2")
            echo "Installing Ophardt on $SERVER"
            break
            ;;
        "Nginx")
            echo "Installing Ophardt on $SERVER"
            break
            ;;
        "Quit")
            exit 0
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

#Make sure that Raspbian and packages are up to date
apt update
apt upgrade -y

#Install Unzip Apache, PHP, PHP Extensions, MariaDB, MySQL Python Connector, Java
apt install unzip mariadb-server python3-mysql.connector openjdk-8-jre ufw certbot -y

#Configure and Enable firewall
ufw allow 'OpenSSH'
ufw allow 'Apache Secure'
ufw --force enable

#Change MySQL configuration
echo '[mysqld]
sql-mode=ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' >> /etc/mysql/conf.d/mysql.cnf
service mysqld restart

if [ $SERVER == "Apache2" ]; then

  #Install Apache, PHP, PHP Extensions, MariaDB, MySQL Python Connector, Java
  apt install apache2 php php-mysql php-xml php-curl php-intl php-zip php-mbstring python3-certbot-apache -y

  #Create secure SSL config for Apache
  cat > /etc/apache2/conf-available/ssl-params.conf << EOF
SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
SSLHonorCipherOrder On
# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the "preload" directive if you understand the implications.
# Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
# Requires Apache >= 2.4
SSLCompression off
SSLUseStapling on
SSLStaplingCache "shmcb:logs/stapling-cache(150000)"
# Requires Apache >= 2.4.11
SSLSessionTickets Off
EOF

  #Enable apache modules and sites
  sudo a2enmod rewrite
  sudo a2enmod ssl
  sudo a2enmod headers
  sudo a2ensite default-ssl
  sudo a2enconf ssl-params

  echo 'zend_extension = "/usr/lib/php/20230831/ioncube_loader_lin_8.3.so"' > /etc/php/8.3/apache2/conf.d/00-ioncube.ini

elif [ $SERVER == "Nginx" ]; then

  #Install Apache, PHP, PHP Extensions, MariaDB, MySQL Python Connector, Java
  apt install nginx php-fpm php-mysql php-xml php-curl php-intl php-zip php-mbstring python3-certbot-nginx -y

  echo 'zend_extension = "/usr/lib/php/20230831/ioncube_loader_lin_8.3.so"' > /etc/php/8.3/fpm/conf.d/00-ioncube.ini

fi

#Secure MySQL installation
mysql_secure_installation

#Download and install IonCube
#wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_armv7l.tar.gz #RaspberryPi
wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_aarch64.tar.gz
tar -zxvf ioncube_loaders_lin_aarch64.tar.gz
cp ioncube/ioncube_loader_lin_8.3.so /usr/lib/php/20230831/
rm -r ioncube*

#Download and install Ophardt Linux Utilities
wget https://fencing.ophardt.online/software/2024-8_7b86t34x76/linux-utils.zip
unzip linux-utils.zip
mv linux-utils /var/www/
rm linux-utils.zip

#Create empty file in root, due to bug in ophardt-update.py for new installations
touch /root/bin

#Run Ophardt Update script to get the latest linux utils
python3 /var/www/linux-utils/updater/ophardt-update.py -s
