#!/bin/bash

sudo yum install -y npm nginx

cd ~/Mercado-scraping/frontend
npm install
npm run build


sudo mkdir -p /usr/share/nginx/html/
sudo rm -rf /usr/share/nginx/html/*
sudo cp -r dist/* /usr/share/nginx/html/
sudo systemctl restart nginx.service




# Copy custom nginx.conf into the correct location
sudo cp ~/Mercado-scraping/aws/nginx.conf /etc/nginx/nginx.conf
  
# Restart Nginx to apply the new config
sudo systemctl restart nginx.service


