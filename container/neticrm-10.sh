#!/bin/bash
date +"@ %Y-%m-%d %H:%M:%S %z"

# wait for mysql start
while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done
sleep 10

DB=$INIT_DB
PW=$INIT_PASSWD
DOMAIN=$INIT_DOMAIN
BASE="/var/www"
DRUPAL="10.1.6"
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
if [ -f /var/www/html/log/php.ini ]; then
  for DIR in /etc/php/* ; do
    if [ -d "$DIR/fpm/conf.d" ]; then
      cd "$DIR/fpm/conf.d" && ln -s /var/www/html/log/php.ini xx-php.ini
      supervisorctl restart php-fpm
    fi
    if [ -d "$DIR/apache2/conf.d" ]; then
      cd "$DIR/apache2/conf.d" && ln -s /var/www/html/log/php.ini xx-php.ini
      supervisorctl restart apache2
    fi
  done
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
    wget https://www.drupal.org/download-latest/tar.gz -O drupal.tar.gz
    tar -zxf drupal.tar.gz -C html --strip-components=1
    rm -Rf drupal.tar.gz
    cd $BASE/html

    # update to latest drupal
    composer update "drupal/core-*" --with-all-dependencies
    composer require drush/drush

    # require phpmailer
    composer require phpmailer/phpmailer

    # third party requirement put here
    ## tfa
    composer require christian-riesen/otp
    composer require chillerlan/php-qrcode
    composer require defuse/php-encryption

    if [ -d $BASE/html/sites/default ]; then
      dd if=/dev/urandom bs=32 count=1 | base64 -i - > /var/www/html/sites/default/tfa.config
    fi
    if [ ! -f $BASE/html/sites/default/services.yml ]; then
      echo -e "parameters:\n  session.storage.options:\n    gc_probability: 1\n    gc_divisor: 100\n    gc_maxlifetime: 80000\n    cookie_lifetime: 80000\n    cookie_samesite: Lax\n  twig.config:\n    debug: false\n    auto_reload: null\n    cache: true\n  filter_protocols:\n    - http\n    - https\n    - tel\n    - mailto\n    - webcal\n" > $BASE/html/sites/default/services.yml
    fi
  fi
  if [ ! -h "$BASE/html/profiles/neticrmp" ]; then
    cd $BASE/html/profiles && ln -s /mnt/neticrm-10/neticrmp neticrmp
  fi
  if [ ! -h "$BASE/html/modules/civicrm" ]; then
    cd $BASE/html/modules && ln -s /mnt/neticrm-10/civicrm civicrm
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

  cd $BASE/html
  sleep 2s
  drush -vv --yes site-install neticrmp --account-mail="${HOST_MAIL}" --account-name=admin --db-url=mysql://${DB}:${PW}@localhost/${DB} --site-mail=${MAIL} --site-name="${SITE}" --locale=zh-hant --yes

  # drupal dirs and files
  cd $BASE/html && find . -type d | xargs chmod 755
  chown -R www-data:www-data $BASE/html/sites/default/files
  chown www-data:www-data $BASE/html/sites/default/*.php
  chmod 440 $BASE/html/sites/default/civicrm.settings.php
  chmod 440 $BASE/html/sites/default/settings.php

  # log dirs and files
  chgrp -R www-data $BASE/html/log
  chmod -R g+w $BASE/html/log
  echo "Done!"
else
  echo "Skip exist $DB, root password already setup before."
fi
date +"@ %Y-%m-%d %H:%M:%S %z"
