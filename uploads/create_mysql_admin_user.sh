#!/bin/bash
sed -i "s/skip-external-locking/skip-external-locking\ninnodb_use_native_aio = 0\n/" /etc/mysql/my.cnf
/usr/bin/mysqld_safe > /dev/null 2>&1 &

RET=1
while [[ RET -ne 0 ]]; do
    echo "=> Waiting for confirmation of MySQL service startup"
    sleep 5
    mysql -uroot -e "status" > /dev/null 2>&1
    RET=$?
done

DBPASS=${MYSQL_PASS:-'admin'}
DBUSER=${MYSQL_USER:-'admin'}
DBNAME=${MYSQL_DBNAME:-'wordpress'}
VIRTUAL_HOST=${VIRTUAL_HOST:-'localhost'}
USER_EMAIL=${USER_EMAIL:-'support@'$VIRTUAL_HOST}
WP_USER=${WP_USER:-'admin'}
WP_PASSTEMP=${WP_PASS:-'password'}
#WP_PASS=$(printf '%s' $WP_PASSTEMP | md5sum)
WP_PASS=$(echo -n $WP_PASSTEMP | md5sum | awk '{print $1}')

_word=$( [ ${MYSQL_PASS} ] && echo "preset" || echo "random" )
echo "=> Creating MySQL $DBUSER user with ${_word} password"
echo "================================================================ "
echo "DB USER => $DBUSER"
echo "DB PASSWORD => $DBPASS"
echo "DB NAME => $DBNAME"
echo "WP USER => $WP_USER"
echo "WP PASS => $WP_PASS"
echo "WP TEMP => $WP_PASSTEMP"
echo "WP MAIL -> $USER_EMAIL"
echo "================================================================ "
mysql -uroot -e "CREATE DATABASE $DBNAME"
mysql -uroot -e "CREATE USER '$DBUSER'@'%' IDENTIFIED BY '$DBPASS'"
mysql -uroot -e "GRANT ALL PRIVILEGES ON $DBNAME.* TO '$DBUSER'@'%' WITH GRANT OPTION"

replace SITENAME ${VIRTUAL_DOMAIN:-'testuser'} -- /var/www/html/configuration.php
replace DBUSER $DBUSER -- /var/www/html/configuration.php 
replace DBPASSWORD $DBPASS -- /var/www/html/configuration.php
replace DBNAME $DBNAME -- /var/www/html/configuration.php 

echo '-----------------------'
echo "filemanager user =>  ${FILEMANAGERUSER:-'testuser'}"
echo "filemanager pass => ${FILEMANAGERPASSWORD:-'testpassword'}"
echo '------------------------'
replace FILEMANAGERUSER ${FILEMANAGERUSER:-'testuser'} -- /usr/share/pbn/filemanager/config/.htusers.php
replace FILEMANAGERPASSWORD $(echo -n ${FILEMANAGERPASSWORD:-'testpassword'} | md5sum | awk '{print $1}') -- /usr/share/pbn/filemanager/config/.htusers.php

replace HOSTID ${HOSTID:-'_1'} -- /usr/share/pbn/apache2.conf
chown -R  www-data:www-data /var/www/html

replace MAIL $USER_EMAIL -- /var/www/html/configuration.php 
replace TABLEPREFIX ${TABLEPREFIX:-'tbl_'} -- /var/www/html/configuration.php

replace TABLEPREFIX ${TABLEPREFIX:-'tbl_'} -- /joomla.sql 
replace USER_USERNAME $WP_USER -- /joomla.sql 
replace USER_EMAIL $USER_EMAIL -- /joomla.sql 
replace PASSWORDHERE $WP_PASS -- /joomla.sql 
mysql -uroot $DBNAME < joomla.sql

rm joomla.sql;

# You can create a /mysql-setup.sh file to intialized the DB
if [ -f /mysql-setup.sh ] ; then
  . /mysql-setup.sh
fi

echo "=> Done!"

echo "========================================================================"
echo "You can now connect to this MySQL Server using:"
echo ""
echo "    mysql -u$DBUSER -p$DBPASS -h<host> -P<port>"
echo ""
echo "Please remember to change the above password as soon as possible!"
echo "MySQL user 'root' has no password but only allows local connections"
echo "========================================================================"

mysqladmin -uroot shutdown
