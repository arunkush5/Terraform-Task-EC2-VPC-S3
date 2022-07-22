#!/bin/bash
apt update
apt upgrade -y
apt install apache2

echo "Hi Arun is Here!!!" > /var/wwww/html/index.html