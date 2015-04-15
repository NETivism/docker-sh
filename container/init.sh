#!/bin/sh
DB=$INIT_DB
PW=$INIT_PASSWD

# init script repository
cd /home/docker
git pull

# init files
echo 'copy files...'
cp -f /home/docker/mysql/my.cnf /etc/mysql/my.cnf
cp -f /home/docker/apache/netivism.conf /etc/apache2/conf.d/
if [ -f /usr/bin/php ]; then
  echo 'copy php settings...'
  PHPVER=`/usr/bin/php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;"`
  ln -s /home/docker/php/default$PHPVER.ini /etc/php5/apache2/conf.d/
fi
echo 'copy done.'

# init log directory
if [ ! -d /var/www/html/log ]; then
  mkdir /var/www/html/log
  chown -R root:adm /var/www/html/log
fi

# init mysql
if [ ! -d /var/lib/mysql/mysql ]; then
  # Setup MySQL data directory.
  echo "Initializing mysql data dir to /var/lib/mysql ..."
  mysql_install_db --datadir=/var/lib/mysql

  /usr/bin/mysqld_safe > /dev/null 2>&1 &

  while (true); do
    sleep 3s
    mysql -uroot -e "status" > /dev/null 2>&1 && break
  done

  mysql -uroot -e "UPDATE mysql.user set Password=PASSWORD('$PW') where user = 'root';"
  mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
  mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
  #mysql -uroot -e "GRANT SELECT, LOCK TABLES ON 'information_schema'.* TO '$DB'@'%';"
  #mysql -uroot -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES, TRIGGER, \
  #    SHOW VIEW, EVENT, CREATE TEMPORARY TABLES ON $DB.* TO '$DB'@'%';"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
  mysql -uroot -e "FLUSH PRIVILEGES;"
  echo "MySQL initialize completed !!"
  echo "MYSQL_DB=$DB"
  echo "MYSQL_PW=$PW"
else
  # if mysql stopped, start it
  echo "MySQL Data dir already exists!"
  /usr/bin/mysqld_safe > /dev/null 2>&1 &
fi

# initialize www server
/usr/sbin/apache2ctl -D FOREGROUND > /dev/null 2>&1 &

# enter to bash interface
/bin/bash
