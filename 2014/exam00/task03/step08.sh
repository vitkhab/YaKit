#!/bin/bash

# Add distribution for memcached
fullname=`uname -n`; order=`echo ${fullname: -1}`
sed -i 's#10.0.2.101#10.0.2.100#g' /var/www/wordpress/wp-config.php
sed -i 's#10.0.2.102#10.0.2.100#g' /var/www/wordpress/wp-config.php
echo "
if ( ("\!"empty( \$_SERVER['HTTP_X_FORWARDED_HOST'])) ||
     ("\!"empty( \$_SERVER['HTTP_X_FORWARDED_FOR'])) ) { 
 
    // http://wordpress.org/support/topic/wordpress-behind-reverse-proxy-1
    \$_SERVER['HTTP_HOST'] = \$_SERVER['HTTP_X_FORWARDED_HOST'];
}

\$memcached_servers = array(
        'default' => array(
                '10.0.2.101:11211',
                '10.0.2.102:11211'
        )
);" >> /var/www/wordpress/wp-config.php

# Change MySQL settings to Master-Master Replication
fullname=`uname -n`; order=`echo ${fullname: -1}`
sed -i "s#bind-address\([ \t]*\)= 127.0.0.1#bind-address\1= 10.0.2.$((100 + order))#" /etc/mysql/my.cnf
echo "[mysqld]
server-id = $order
auto_increment_offset = $order
auto_increment_increment = 2
log-bin = /var/lib/mysql/mysql-bin.log
log-bin-index = /var/lib/mysql/mysql-bin.index
binlog-ignore-db = information_schema
binlog-ignore-db = mysql
replicate-ignore-db = mysql
replicate-ignore-db = information_schema
relay-log = /var/log/mysql/slave-relay-bin
relay-log-index = /var/log/mysql/slave-relay-bin.index" > /etc/mysql/conf.d/replication.cnf
echo "GRANT REPLICATION SLAVE ON *.* to 'replication'@'%' IDENTIFIED BY 'replication'" | mysql -u root -proot
echo "GRANT ALL PRIVILEGES ON *.* to 'dbadmin'@'%' IDENTIFIED BY 'dbadmin'" | mysql -u root -proot
echo "FLUSH PRIVILEGES" | mysql -u root -proot
service mysql restart
echo "CHANGE MASTER TO MASTER_HOST = '"10.0.2.$((order % 2 + 101))"', MASTER_USER = 'replication', MASTER_PASSWORD = 'replication'" | mysql -u root -proot

# Install balancer and linux-ha
apt-get install -y heartbeat nginx
echo "auth 2
2 sha1 test-ha" > /etc/ha.d/authkeys
chmod 600 /etc/ha.d/authkeys
echo "logfile /var/log/ha-log
logfacility local0
keepalive 2
deadtime 30
initdead 120
bcast eth0
udpport 694
auto_failback off
node yakit-z01
node yakit-z02" > /etc/ha.d/ha.cf
echo "yakit-z01 10.0.2.100 nginx" > /etc/ha.d/haresources
echo 'user www-data;
worker_processes 4;
pid /run/nginx.pid;
events {
        worker_connections 768;
}
http {
    upstream wordpress {
        server 10.0.2.101;
        server 10.0.2.102;
    }
    server {
        listen 10.0.2.100:80;
        server_name  http://10.0.2.100:80; 
        location / {
            proxy_pass http://wordpress;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Queue-Start "t=${msec}000";
        }
    }
}' > /etc/nginx/nginx.conf

# Restart services and flush memcached
echo "flush_all" | /bin/netcat -q 2 127.0.0.1 11211
service nginx stop
service heartbeat start