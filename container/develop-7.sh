#!/bin/bash
date +"@ %Y-%m-%d %H:%M:%S %z"

# wait for mysql start
while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done
sleep 10

DB=$INIT_DB
PW=$INIT_PASSWD
DOMAIN=$INIT_DOMAIN
BASE="/var/www"
DRUPAL="7.100"
SITE=$INIT_NAME
MAIL=$INIT_MAIL
HOST_MAIL=$HOST_MAIL

# init script repository
cd /home/docker && git pull

# init log directory
if [ ! -d /var/www/html/log ]; then
  mkdir /var/www/html/log
  chown root /var/www/html/log
fi
chgrp -R www-data $BASE/html/log && chmod -R g+ws $BASE/html/log
if [ -f /var/www/html/log/php.ini ]; then
  if [ -d /etc/php5/fpm/conf.d ]; then
    cd /etc/php5/fpm/conf.d && ln -s /var/www/html/log/php.ini xx-php.ini
    supervisorctl restart php-fpm
  fi
  for DIR in /etc/php/* ; do
    if [ -d "$DIR/fpm/conf.d" ]; then
      cd "$DIR/fpm/conf.d" && ln -s /var/www/html/log/php.ini xx-php.ini
      supervisorctl restart php-fpm
    fi
  done
  if [ -d /etc/php5/apache2/conf.d ]; then
    cd /etc/php5/apache2/conf.d && ln -s /var/www/html/log/php.ini xx-php.ini
    supervisorctl restart apache2
  fi
  sleep 3
fi
if [ -f /var/lib/mysql/mysql.cnf ] && [ -d /var/lib/mysql ]; then
  cd /etc/mysql/conf.d && ln -s /var/lib/mysql/mysql.cnf custom.cnf
  supervisorctl restart mysql
  sleep 3
fi

# init mysql
DB_TEST=`mysql -uroot -sN -e "SHOW databases"`
MYSQL_ACCESS=$?
DB_EXISTS=`mysql -uroot -sN -e "SHOW databases" | grep $DB`

if [ $MYSQL_ACCESS -eq 0 ] && [ -z "$DB_EXISTS" ] && [ -n "$DB" ]; then
  mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
  mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
  mysql -uroot -e "CREATE USER '$DB'@'localhost' IDENTIFIED BY '$PW';"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'localhost' WITH GRANT OPTION;"
  mysql -uroot -e "UPDATE mysql.user set Password=PASSWORD('$PW') where user = 'root';"
  mysql -uroot -e "FLUSH PRIVILEGES;"
  echo "MySQL initialize completed !!"
  echo "MYSQL_DB=$DB"
  echo "MYSQL_PW=$PW"

  if [ -f "$BASE/html/index.php" ]; then
    DRUPAL_EXISTS=`cat $BASE/html/index.php | grep drupal`
  else
    DRUPAL_EXISTS=""
  fi
  if [ -z "$DRUPAL_EXISTS" ]; then
    date +"@ %Y-%m-%d %H:%M:%S %z"
    echo "Install Drupal ..."
    cd $BASE
    drush dl drupal-${DRUPAL}
    mv $BASE/drupal-${DRUPAL}/* $BASE/html/
    mv $BASE/drupal-${DRUPAL}/.htaccess $BASE/html/
    rm -Rf $BASE/drupal-${DRUPAL}
  fi
  if [ ! -h "$BASE/html/profiles/neticrmp" ]; then
    cd $BASE/html/profiles && cp -af /mnt/neticrm-7/neticrmp neticrmp
  fi
  if [ ! -h "$BASE/html/sites/all/modules/civicrm" ]; then
    cd $BASE/html/sites/all/modules && cp -af /mnt/neticrm-7/civicrm civicrm
  fi
  # make sure drush have correct base_url
  if [ ! -f "$BASE/html/sites/default/drushrc.php" ]; then
    echo -e "<?php\n\$options['uri'] = 'http://$INIT_DOMAIN';\n\$options['php-notices'] = 'warning';" > $BASE/html/sites/default/drushrc.php;
  fi

  if [ ! -d "$BASE/html/profiles/neticrmp" ]; then
    echo "Error: Profile not found. (missing neticrmp)"
    exit 1
  fi
  if [ -f $BASE/html/sites/default/settings.php ]; then
    echo "Error: Drupal already installed. (found settings.php)"
    exit 1
  fi
  if [ -f $BASE/html/sites/default/civicrm.settings.php ]; then
    echo "Error: CiviCRM already installed. (found civicrm.settings.php)"
    exit 1
  fi

  cd $BASE/html/sites/default
  cat <<EOT > /tmp/conn.txt
\$databases['default']['default'] = array(
  'driver' => 'mysql',
  'database' => '${DB}',
  'username' => '${DB}',
  'password' => '${PW}',
  'host' => 'localhost',
  'charset' => 'utf8mb4',
  'collation' => 'utf8mb4_general_ci',
);
EOT

  sed '/$databases = array();/r /tmp/conn.txt' default.settings.php > settings.php
  sed -i '/$databases = array();/d' settings.php
  rm /tmp/conn.txt
  SALT=`tr -dc '1234567890!_qwertyuiopQWERTYUIOPas!dfg0hjk0lASDFGHJKL!zxcvbnmZXCVBNM' < /dev/urandom | head -c48; echo ""`
  sed -i "s/\$drupal_hash_salt = '';/\$drupal_hash_salt = '${SALT}';/g" settings.php

  cd $BASE/html
  php ~/.composer/vendor/bin/drush.php site-install neticrmp --account-mail="${HOST_MAIL}" --account-name=admin --account-pass=${PW} --db-url=mysql://${DB}:${PW}@localhost/${DB} --site-mail=${MAIL} --site-name="${SITE}" --locale=zh-hant --yes

  cd $BASE && chown -R www-data:www-data html
  echo "Done!"
else
  echo "Skip exist $DB, root password already setup before."
fi
date +"@ %Y-%m-%d %H:%M:%S %z"

