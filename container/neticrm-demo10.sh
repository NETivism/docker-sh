#!/bin/bash
date +"@ %Y-%m-%d %H:%M:%S %z"

# wait for mysql start
while ! pgrep -u mysql mysqld > /dev/null; do sleep 3; done
sleep 10

DB=$INIT_DB
PW=$INIT_PASSWD
DOMAIN=$INIT_DOMAIN
BASE="/var/www"
DRUPAL="10.6.3"
LATEST_VERSION=$(curl -s "https://www.drupal.org/node/3060/release/feed?version=$VERSION_PREFIX" | grep '<title>drupal' | grep -v 'alpha\|beta\|dev\|-rc' | head -1 | sed 's/[^0-9.]*//g' | tr -d '\n')
if [ -n "$LATEST_VERSION" ] && [ "${LATEST_VERSION:0:2}" = "10" ]; then
  DRUPAL=$LATEST_VERSION;
fi

SITE=$INIT_NAME
MAIL="mis@netivism.com.tw"
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

## update composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
composer global remove drush/drush

# init mysql
DB_TEST=`mysql -uroot -sN -e "SHOW databases"`
MYSQL_ACCESS=$?
DB_EXISTS=`ls -1 /var/lib/mysql/ | grep $INIT_DB`

function clear_demo() {
  # add clear.sql
  echo "SET FOREIGN_KEY_CHECKS = 0; SET GROUP_CONCAT_MAX_LEN=32768; SET @tables = NULL; SELECT GROUP_CONCAT('\`', table_name, '\`') INTO @tables FROM information_schema.tables WHERE table_schema = (SELECT DATABASE()); SELECT IFNULL(@tables,'dummy') INTO @tables; SET @tables = CONCAT('DROP TABLE IF EXISTS ', @tables); PREPARE stmt FROM @tables; EXECUTE stmt; DEALLOCATE PREPARE stmt; SET FOREIGN_KEY_CHECKS = 1;" > /tmp/cleardb.sql
  mysql -u$DB -p$PW $DB < /tmp/cleardb.sql

  if [ -f $BASE/html/sites/default/settings.php ]; then
    rm -f $BASE/html/sites/default/settings.php
    chmod 755 $BASE/html/sites/default
  fi
  if [ -f $BASE/html/sites/default/civicrm.settings.php ]; then
    rm -f $BASE/html/sites/default/civicrm.settings.php
  fi
  if [ -d $BASE/html/sites/default/files ]; then
    rm -Rf $BASE/html/sites/default/files
  fi
}

function create_demo() {
  cd $BASE/html

  # set PATH for current script execution
  export PATH="/var/www/html/vendor/bin:$PATH"

  # Install site with demo data
  php -d sendmail_path=`which true` /var/www/html/vendor/bin/drush -vv --yes site-install neticrmp variables.civicrm_demo_sample_data=1 --account-mail="${MAIL}" --account-name=admin --account-pass="${PW}" --db-url=mysql://${DB}:${PW}@localhost/${DB} --site-mail=${MAIL} --site-name="${SITE}" --locale=zh-hant --yes

  # add mailing and additional settings
  echo "defined('VERSION') ? @include_once('/mnt/neticrm-'.substr(VERSION, 0, strpos(VERSION, '.')).'/global.inc') : @include_once('/mnt/neticrm-6/global.inc');" >> $BASE/html/sites/default/settings.php
  echo "if(is_file(dirname(__FILE__).'/smtp.settings.php')){ @include_once('smtp.settings.php'); }" >> $BASE/html/sites/default/settings.php
  echo "if(is_file(dirname(__FILE__).'/local.settings.php')){ @include_once('local.settings.php'); }" >> $BASE/html/sites/default/settings.php

  cd $BASE && chown -R www-data:www-data html
  cd $BASE/html

  # Create demo users
  drush user-create demo --password="demoneticrm" --mail="demo@netivism.com.tw"
  drush user-add-role "網站總管" "demo"
  drush user-create demouser --password="demoneticrm" --mail="demo+user@netivism.com.tw"

  # Set welcome message (using config set for Drupal 10)
  drush config-set neticrm.settings welcome_message "歡迎您來到 netiCRM示範網站！本網站為測試用途，資料隨時清除，請勿留下個資以免外洩。測試帳號/密碼請用 demo / demoneticrm 登入。<br>如有任何問題，請至 <a href='https://neticrm.tw'>https://neticrm.tw</a> 與我們聯繫。" -y

  # drupal dirs and files
  cd $BASE/html && find . -type d | xargs chmod 755
  chown -R www-data:www-data $BASE/html/sites/default/files
  chown www-data:www-data $BASE/html/sites/default/*.php
  chmod 440 $BASE/html/sites/default/civicrm.settings.php
  chmod 440 $BASE/html/sites/default/settings.php

  # log dirs and files
  chgrp -R www-data $BASE/html/log
  chmod -R g+w $BASE/html/log
}

if [ -z "$DB_EXISTS" ] && [ $MYSQL_ACCESS -eq 0 ] && [ -n "$DB" ]; then
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
    DRUPAL_EXISTS=`cat $BASE/html/index.php | grep Drupal`
  else
    DRUPAL_EXISTS=""
  fi
  if [ -z "$DRUPAL_EXISTS" ]; then
    date +"@ %Y-%m-%d %H:%M:%S %z"
    echo "Install Drupal ..."
    cd $BASE
    wget https://ftp.drupal.org/files/projects/drupal-${DRUPAL}.tar.gz -O drupal.tar.gz
    tar -zxf drupal.tar.gz -C html --strip-components=1
    rm -Rf drupal.tar.gz
    cd $BASE/html

    # update to latest drupal
    composer update "drupal/core-*" --with-all-dependencies

    # correct drush installation
    cd $BASE/html
    composer require drush/drush

    # add drush to PATH in bash.bashrc for future sessions
    if ! grep -q "/var/www/html/vendor/bin" /etc/bash.bashrc; then
      echo 'export PATH="/var/www/html/vendor/bin:$PATH"' >> /etc/bash.bashrc
      cd /usr/local/bin && ln -s /var/www/html/vendor/bin/drush drush
      cd $BASE/html
    fi

    # set PATH for current script execution
    export PATH="/var/www/html/vendor/bin:$PATH"

    # require phpmailer
    composer require phpmailer/phpmailer

    # third party requirement put here
    ## tfa
    composer require christian-riesen/otp
    composer require chillerlan/php-qrcode
    composer require defuse/php-encryption

    # Install bootstrap_barrio theme
    echo "Installing bootstrap_barrio theme..."
    if ! composer require 'drupal/bootstrap_barrio:^5.5'; then
      echo "Warning: Failed to install bootstrap_barrio. Theme setup will be skipped."
      echo "You can manually install it later with: composer require 'drupal/bootstrap_barrio:^5.5'"
    fi

    if [ -d $BASE/html/sites/default ]; then
      dd if=/dev/urandom bs=32 count=1 | base64 -i - > /var/www/html/sites/default/tfa.config
    fi
    if [ ! -f $BASE/html/sites/default/services.yml ]; then
      echo -e "parameters:\n  session.storage.options:\n    gc_probability: 1\n    gc_divisor: 100\n    gc_maxlifetime: 48000\n    cookie_lifetime: 48000\n    cookie_samesite: Lax\n  twig.config:\n    debug: false\n    auto_reload: null\n    cache: true\n  filter_protocols:\n    - http\n    - https\n    - tel\n    - mailto\n    - webcal\n" > $BASE/html/sites/default/services.yml
    fi
  fi
  if [ ! -h "$BASE/html/profiles/neticrmp" ]; then
    cd $BASE/html/profiles && ln -s /mnt/neticrm-10/neticrmp neticrmp
  fi
  if [ ! -h "$BASE/html/modules/civicrm" ]; then
    cd $BASE/html/modules && ln -s /mnt/neticrm-10/civicrm civicrm
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

  create_demo

  echo "Done!"
elif [ -n "$DB_EXISTS" ]; then
  echo "Clear exists demo site data..."
  clear_demo
  echo "Create new demo site"
  create_demo
else
  echo "Skip exist $DB, root password already setup before."
fi
date +"@ %Y-%m-%d %H:%M:%S %z"
