#!/bin/bash
#Prerequisite - License file needs to be in the same directory as this script
#I.e. from you locale computer: SCP ophardt_license.yml pi@x.x.x.x:

#Copy licensefile to it's required destination and start the update
sudo cp ophardt_license.yml /var/www/linux-utils/updater/
sudo /var/www/linux-utils/bin/softwareupdate -d

#Fix file permissions
chown -R www-data:www-data /var/www/fencing/*
chmod -R 0744 /var/www/fencing/*
chmod 0755 -R /var/www/fencing/OphardtSync/
chmod 0440 /var/www/fencing/app/config/ophardt_license.yml

#Restart Apache
service apache2 restart
