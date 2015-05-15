#!/bin/bash
DB=$INIT_DB
PW=$INIT_PASSWD

# init script repository
cd /var/ansible/docker

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

  mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
  mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
  mysql -uroot -e "UPDATE mysql.user set Password=PASSWORD('$PW') where user = 'root';"
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
