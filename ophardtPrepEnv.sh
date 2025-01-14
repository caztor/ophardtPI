#!/bin/bash
# Script to prepare new demo environments, update core software, or reset specific environments
# Includes error handling, scalability, and modularity improvements

# Constants
BASE_DIR="/var/www/ophardttouch"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
SSL_CERTS="/etc/ssl/certs"
SSL_KEYS="/etc/ssl/private"
MYSQL_USER="root"
HOSTSUFFIX="student"

# Functions
error_exit() {
    echo "[ERROR] $1"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "Please run as root (sudo)."
    fi
}

validate_numeric_input() {
    local input=$1
    local min=$2
    local max=$3
    [[ "$input" =~ ^[0-9]+$ ]] && ((input >= min && input <= max)) || return 1
}

validate_domain() {
    local domain=$1
    [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || return 1
}

get_user_input() {
    echo "Choose an option:"
    echo "1. Deploy new environments"
    echo "2. Reset a specific environment"
    read -p "Enter your choice (1 or 2): " OPTION
    if [[ "$OPTION" == "1" ]]; then
        get_new_environment_details
    elif [[ "$OPTION" == "2" ]]; then
        get_reset_environment_details
    else
        error_exit "Invalid option selected."
    fi
}

get_new_environment_details() {
    while true; do
        echo "How many demo environments should we build?"
        read -p "Input number (between 1-19): " ENVCOUNT
        if validate_numeric_input "$ENVCOUNT" 1 19; then break; fi
        echo "You need to enter a valid value!"
    done

    while true; do
        read -p "Input domain suffix (e.g., example.com): " DOMAIN
        if validate_domain "$DOMAIN"; then break; fi
        echo "Invalid domain format. Please use a standard domain format (e.g., example.com)."
    done

    read -sp "Input root password for the MySQL database: " DBPASS
    echo
}

get_reset_environment_details() {
    read -p "Input the environment number to reset (e.g., 1 for student1): " ENVNUM
    if validate_numeric_input "$ENVNUM" 1 19; then
        HOSTNAME="${HOSTSUFFIX}${ENVNUM}"
        while true; do
            read -p "Input domain suffix (e.g., example.com): " DOMAIN
            if validate_domain "$DOMAIN"; then break; fi
            echo "Invalid domain format. Please use a standard domain format (e.g., example.com)."
        done

        read -sp "Input root password for the MySQL database: " DBPASS
        echo
        if ! environment_exists "$HOSTNAME"; then
            error_exit "Environment $HOSTNAME.$DOMAIN does not exist."
        fi
    else
        error_exit "Invalid environment number."
    fi
}

environment_exists() {
    local hostname=$1
    [ -d "/var/www/$hostname" ] || [ -f "$NGINX_AVAILABLE/$hostname.$DOMAIN" ]
}

clean_environment() {
    echo "Cleaning environment $HOSTNAME..."
    
    if [ -d "/var/www/$HOSTNAME" ]; then
        rm -Rf "/var/www/$HOSTNAME" || error_exit "Failed to remove files for $HOSTNAME."
    else
        echo "[INFO] Directory /var/www/$HOSTNAME does not exist. Skipping cleanup."
    fi

    rm -f "$NGINX_AVAILABLE/$HOSTNAME.$DOMAIN" "$NGINX_ENABLED/$HOSTNAME.$DOMAIN" || \
        echo "[INFO] Nginx configurations for $HOSTNAME not found. Skipping cleanup."
    
    rm -f "$SSL_CERTS/$HOSTNAME.$DOMAIN.crt" "$SSL_KEYS/$HOSTNAME.$DOMAIN.key" || \
        echo "[INFO] SSL certificates for $HOSTNAME not found. Skipping cleanup."
    
    echo "Dropping database for $HOSTNAME..."
    echo "DROP DATABASE IF EXISTS $HOSTNAME;" | mysql -u"$MYSQL_USER" -p"$DBPASS" || \
        error_exit "Failed to drop database for $HOSTNAME."
}

setup_environment() {
    echo "Deploying environment $HOSTNAME.$DOMAIN..."
    
    mkdir -p "/var/www/$HOSTNAME" || error_exit "Failed to create directory /var/www/$HOSTNAME."
    cp -R "$BASE_DIR" "/var/www/$HOSTNAME" || error_exit "Failed to copy base files."
    
    cp "./logo/logo$ENVNUM.png" "/var/www/$HOSTNAME/web/img/logo.png" || error_exit "Failed to copy logo."

    chown -R www-data:www-data "/var/www/$HOSTNAME" || error_exit "Failed to set ownership."
    chmod -R 0744 "/var/www/$HOSTNAME" || error_exit "Failed to set permissions."

    sed -i "s/score_fencing/$HOSTNAME/g" "/var/www/$HOSTNAME/app/config/parameters.yml" || \
        error_exit "Failed to update configuration."

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_KEYS/$HOSTNAME.$DOMAIN.key" \
        -out "$SSL_CERTS/$HOSTNAME.$DOMAIN.crt" \
        -subj "/C=DK/ST=DK/L=Copenhagen/O=Ophardt Touch Demo/OU=IT/CN=$HOSTNAME.$DOMAIN" || \
        error_exit "Failed to generate certificates."

    create_nginx_config
    activate_nginx_config
    create_database
}

create_nginx_config() {
    echo "Creating virtual host configuration for $HOSTNAME.$DOMAIN..."
    cat > "$NGINX_AVAILABLE/$HOSTNAME.$DOMAIN" <<EOF
server {
    listen 443 ssl http2;
    server_name $HOSTNAME.$DOMAIN;

    root /var/www/$HOSTNAME/web;
    index app.php;

    ssl_certificate $SSL_CERTS/$HOSTNAME.$DOMAIN.crt;
    ssl_certificate_key $SSL_KEYS/$HOSTNAME.$DOMAIN.key;

    location / {
        try_files \$uri \$uri/ /app.php?a=\$uri;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.2-fpm.sock;
    }
}
EOF
}

activate_nginx_config() {
    ln -s "$NGINX_AVAILABLE/$HOSTNAME.$DOMAIN" "$NGINX_ENABLED/$HOSTNAME.$DOMAIN" || \
        error_exit "Failed to activate Nginx configuration."
}

create_database() {
    echo "Creating database for $HOSTNAME..."
    echo "CREATE DATABASE $HOSTNAME;" | mysql -u"$MYSQL_USER" -p"$DBPASS" || error_exit "Failed to create database."
    echo "GRANT ALL PRIVILEGES ON $HOSTNAME.* TO 'scoring'@'localhost';" | mysql -u"$MYSQL_USER" -p"$DBPASS" || \
        error_exit "Failed to set database permissions."
    mysqldump -R -u"$MYSQL_USER" -p"$DBPASS" score_fencing | mysql -u"$MYSQL_USER" -p"$DBPASS" "$HOSTNAME" || \
        error_exit "Failed to import base database."
}

reload_services() {
    systemctl restart php-fpm || error_exit "Failed to restart PHP-FPM."
    nginx -s reload || error_exit "Failed to reload Nginx."
}

# Main Script
check_root
get_user_input

if [[ "$OPTION" == "1" ]]; then
    for ((i = 1; i <= ENVCOUNT; i++)); do
        HOSTNAME="${HOSTSUFFIX}$i"
        setup_environment
    done
elif [[ "$OPTION" == "2" ]]; then
    clean_environment
    setup_environment
fi

reload_services
echo "Operation completed successfully!"
