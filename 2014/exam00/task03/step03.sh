#!/bin/bash

# Make clean grub configuration
update-grub  
grub-install /dev/sda
grub-install /dev/sdb

# Install prerequisite
debconf-set-selections <<< "mysql-server mysql-server/root_password password root"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password root"
apt-get install -y libapache2-mod-php5 php5-mysql mysql-server ssh

# Download and unpack wordpress
wget https://wordpress.org/latest.tar.gz
tar xf latest.tar.gz -C /var/www/

# Create wordpress DB
echo 'CREATE DATABASE wordpress' | mysql -u root -proot
echo 'GRANT ALL PRIVILEGES ON wordpress.* TO "wordpress"@"localhost" IDENTIFIED BY "wordpress"' | mysql -u root -proot

# Create wordpress config
fullname=`uname -n`; order=`echo ${fullname: -1}`
echo "<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', 'wordpress');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('AUTH_KEY',         '_:6) bt;(3\$0E^D%vr%=&Fk)17.Jp^VLgw/7TXpE>3_CD1jH\$}n|*CZ&h[f@wJk^');
define('SECURE_AUTH_KEY',  '_Dd\${3B5dLn#[_n/RB.bB.fs!( yduBaY5~6+/OK+>@. RmGAXq=^5~e<40]]-Ka');
define('LOGGED_IN_KEY',    'HHKx~<\$x^ZBX LdEROQv{<Zy&:[>g59)vB6/Fa*#A(YF^>.XcRR[27I#P>?7iki7');
define('NONCE_KEY',        'L\$A2vZpEZ@usR\$}q?%UVbJcBSh\$ln+\$Z;2?3L-rx%*< &+?RO=#UpB.fmvHE)52r');
define('AUTH_SALT',        's|PtI=z:-o8^!X+@)jHu30MFJ]Ox%UGgr3~o=lNMv!kk+yB3|7Fu<Y3vZX3)+ZoO');
define('SECURE_AUTH_SALT', '1RF(VO+Ca)\$.4]w}u%cuV=T#{05%~CagGXGrsjJl4Zy.q{>ZUa6^M _[!uM-wo^%');
define('LOGGED_IN_SALT',   ' |\$ ZgQ?Ta k5\$M+I>i g<F/RlQDu-</LdU+z]G4I8^QRl~|P#PU*+|9w[qJ_;r*');
define('NONCE_SALT',       'u3!h1,c0#d.cN(z 6DSDAah7x4a7S0UfQ]weZ^<vM4|@zRI)M|D}&:2k\$U_8* z^');
\$table_prefix  = 'wp_';
define('WP_DEBUG', false);
if ( "\!"defined('ABSPATH') )
     define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
define('WP_HOME', 'http://10.0.2."$((100 + order))"');
define('WP_SITEURL', 'http://10.0.2."$((100 + order))"');
" > /var/www/wordpress/wp-config.php

# To be sure that apache2 has access to wordpress files
chown www-data:www-data /var/www/wordpress

# Make apache2 config changes
sed -i 's#DocumentRoot /var/www/html#DocumentRoot /var/www/wordpress#' /etc/apache2/sites-available/000-default.conf
sed -i -r 's#MaxRequestWorkers[ \t]+[0-9]+#MaxRequestWorkers 100#' /etc/apache2/mods-available/mpm_prefork.conf
ipaddr=`ifconfig eth0 | grep 'inet addr' | awk -F: '{print $2;}' | awk '{print $1;}'`
sed -i "s#Listen 80#Listen $ipaddr:80#" /etc/apache2/ports.conf
service apache2 restart