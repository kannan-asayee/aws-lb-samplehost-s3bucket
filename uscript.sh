#!/bin/bash
sudo yum update -y

sleep 15s
sudo yum install httpd -y

sleep 10s

sudo yum install awscli

sleep 15s

sudo aws s3 cp s3://myasayeelabprojectwebsite2024/index.html /var/www/html

sudo systemctl restart httpd.service
