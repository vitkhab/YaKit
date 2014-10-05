#!/bin/bash

# Install prerequisite
apt-get install -y php5-memcache memcached unzip

# Install wordpress plugin for memcached
wget https://downloads.wordpress.org/plugin/memcached.2.0.2.zip
unzip memcached.2.0.2.zip
mv memcached/object-cache.php /var/www/wordpress/wp-content/

# Optimize MySQL for wordpress
sed -i 's#query_cache_size = [0-9]+M#query_cache_size = 32M#' /etc/mysql/my.cnf
sed -i 's#query_cache_limit = [0-9]+M#query_cache_limit = 1M#' /etc/mysql/my.cnf
echo "[mysqld]
innodb_buffer_pool_size = 192M
innodb_flush_log_at_trx_commit = 2" > /etc/mysql/conf.d/innodb.cnf

# Restart services with changed configuration
service apache2 restart
service mysql restart