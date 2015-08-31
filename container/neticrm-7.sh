#!/bin/bash
date +"@ %Y-%m-%d %H:%M:%S %z"

# wait for mysql start
while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done

DB=$INIT_DB
PW=$INIT_PASSWD
BASE="/var/www"
DRUPAL="7.39"
SITE="NAME"
MAIL="mis@netivism.com.tw"

# init script repository
cd /home/docker && git pull

# init log directory
if [ ! -d /var/www/html/log ]; then
  mkdir /var/www/html/log
  chown root /var/www/html/log
fi
chgrp -R www-data $BASE/html/log && chmod -R g+ws $BASE/html/log

# init mysql
DB_EXISTS=`mysql -uroot -sN -e "SHOW databases" | grep $DB` 

if [ -z "$DB_EXISTS" ] && [ -n "$DB" ]; then
  mysql -uroot -e "CREATE DATABASE $DB CHARACTER SET utf8 COLLATE utf8_general_ci;"
  mysql -uroot -e "CREATE USER '$DB'@'%' IDENTIFIED BY '$PW';"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON $DB.* TO '$DB'@'%' WITH GRANT OPTION;"
  mysql -uroot -e "UPDATE mysql.user set Password=PASSWORD('$PW') where user = 'root';"
  mysql -uroot -e "FLUSH PRIVILEGES;"
  echo "MySQL initialize completed !!"
  echo "MYSQL_DB=$DB"
  echo "MYSQL_PW=$PW"

  if [ ! -d "$BASE/html/includes" ]; then
    date +"@ %Y-%m-%d %H:%M:%S %z"
    echo "Install Drupal ..."
    cd $BASE 
    drush dl drupal-${DRUPAL}
    mv $BASE/drupal-${DRUPAL}/* $BASE/html/
    mv $BASE/drupal-${DRUPAL}/.htaccess $BASE/html/
    rm -f $BASE/drupal-${DRUPAL}
    if [ ! -h "$BASE/html/profiles/neticrmp" ]; then
      cd $BASE/html/profiles && ln -s /mnt/neticrm-7/neticrmp neticrmp
    fi
    if [ ! -h "$BASE/html/sites/all/modules/civicrm" ]; then
      cd $BASE/html/sites/all/modules && ln -s /mnt/neticrm-7/civicrm civicrm
    fi
    if [ ! -d "$BASE/html/profiles/neticrmp" ]; then
      echo "neticrmp not found"
      exit 1
    fi

    php -d sendmail_path=`which true` ~/.composer/vendor/bin/drush.php site-install neticrmp --account-mail=${MAIL} --account-name=admin --account-pass=${PW} --db-url=mysql://${DB}:${PW}@127.0.0.1/${DB} --site-mail=${MAIL} --site-name="${SITE}" --locale=zh-hant --yes

    cd $BASE && chown -R www-data:www-data html
    echo "Done!"
  fi
else
  echo "Skip exist $DB, root password already setup before."
fi
date +"@ %Y-%m-%d %H:%M:%S %z"

