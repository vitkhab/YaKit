#!/bin/bash

# Install prerequisites
apt-get install -y apache2 ssh mysql-client

# Just to be sure
echo "STOP SLAVE" | mysql -h 10.0.2.101 -u dbadmin -pdbadmin
echo "STOP SLAVE" | mysql -h 10.0.2.102 -u dbadmin -pdbadmin

# Sync databases
mysqldump -u dbadmin -pdbadmin -h 10.0.2.101 wordpress > /tmp/wordpress.sql
sed -i 's#10.0.2.101#10.0.2.100#g' /tmp/wordpress.sql
mysql -u dbadmin -pdbadmin -h 10.0.2.102 wordpress < /tmp/wordpress.sql

# Sync replication
filename=`echo 'show master status\G' | mysql -h 10.0.2.101 -u dbadmin -pdbadmin | grep File | awk -F': ' '{print $2;}'`
position=`echo 'show master status\G' | mysql -h 10.0.2.101 -u dbadmin -pdbadmin | grep Position | awk -F': ' '{print $2;}'`
echo "CHANGE MASTER TO MASTER_LOG_FILE='"$filename"', MASTER_LOG_POS=$position" | mysql -h 10.0.2.102 -u dbadmin -pdbadmin
filename=`echo 'show master status\G' | mysql -h 10.0.2.102 -u dbadmin -pdbadmin | grep File | awk -F': ' '{print $2;}'`
position=`echo 'show master status\G' | mysql -h 10.0.2.102 -u dbadmin -pdbadmin | grep Position | awk -F': ' '{print $2;}'`
echo "CHANGE MASTER TO MASTER_LOG_FILE='"$filename"', MASTER_LOG_POS=$position" | mysql -h 10.0.2.101 -u dbadmin -pdbadmin

# Start replication
echo "START SLAVE" | mysql -h 10.0.2.101 -u dbadmin -pdbadmin
echo "START SLAVE" | mysql -h 10.0.2.102 -u dbadmin -pdbadmin

#echo "UPDATE wp_options SET option_value = 'http://10.0.2.100:80' WHERE option_name = 'siteurl' OR option_name = 'home'" |  mysql -h 10.0.2.101 -u dbadmin -pdbadmin wordpress

# Make config for yandex tank
echo "[phantom]
address = 10.0.2.100
port = 80
rps_schedule = step(1,60,1,1m)
header_http = 1.1
headers = [Host: yakit-z03]
  [User-Agent: Yandex-tank]
  [Connection: close]
  [Accept-Encoding:gzip,deflate]
uris = /" > ./load.ini

# Launch yandex tank
yandex-tank

# Move reports to web server
rm /var/www/html/index.html
ls ./*/report* | while read i; do date=`echo $i | cut -d'/' -f2 | cut -d'.' -f1`; mv $i /var/www/html/report_$date.html; done