#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (or via sudo)."
    exit 1
fi

###############################
# Check and Install NGINX
###############################
if ! command -v nginx &>/dev/null; then
    echo "NGINX is not installed. Installing NGINX..."
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y nginx
        echo "NGINX installation completed."
    elif command -v yum &>/dev/null; then
        yum install -y epel-release
        yum install -y nginx
        echo "NGINX installation completed."
    else
        echo "No supported package manager found (apt-get or yum). Please install NGINX manually."
        exit 1
    fi
else
    echo "NGINX is already installed."
fi

###############################
# Check and Install Certbot
###############################
if ! command -v certbot &>/dev/null; then
    echo "Certbot is not installed. Installing Certbot..."
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
        echo "Certbot installation completed."
    elif command -v yum &>/dev/null; then
        yum install -y certbot python3-certbot-nginx
        echo "Certbot installation completed."
    else
        echo "No supported package manager found (apt-get or yum). Please install Certbot manually."
        exit 1
    fi
else
    echo "Certbot is already installed."
fi

###############################
# Domain and Docker Container Details
###############################
read -p "Enter your domain (e.g., example.com): " DOMAIN
read -p "Enter the Docker container's IP (default: 127.0.0.1): " DOCKER_IP
if [ -z "$DOCKER_IP" ]; then
    DOCKER_IP="127.0.0.1"
fi
read -p "Enter the Docker container's port (e.g., 8000): " DOCKER_PORT

###############################
# Create NGINX Reverse Proxy Configuration
###############################
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
CONFIG_FILE="$NGINX_AVAILABLE/$DOMAIN"

echo "Creating NGINX reverse proxy configuration for $DOMAIN..."
cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    location / {
        proxy_pass http://$DOCKER_IP:$DOCKER_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site by linking the configuration file
if [ ! -L "$NGINX_ENABLED/$DOMAIN" ]; then
    ln -s "$CONFIG_FILE" "$NGINX_ENABLED/"
    echo "Site enabled: Linked $CONFIG_FILE to $NGINX_ENABLED/"
fi

###############################
# Test and Reload NGINX
###############################
echo "Testing NGINX configuration..."
if nginx -t; then
    echo "Reloading NGINX..."
    systemctl reload nginx
else
    echo "NGINX configuration test failed. Please review the configuration."
    exit 1
fi

###############################
# Obtain and Install SSL Certificate via Certbot
###############################
echo "Obtaining SSL certificate for $DOMAIN..."
certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN"

echo "Reverse proxy configuration complete for $DOMAIN."
