#!/bin/bash
date +"@ %Y-%m-%d %H:%M:%S %z"

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
  done
  sleep 3
fi

#42010, install ffmpeg
if [ $(dpkg -l | grep "^ii.*ffmpeg" | wc -l) -eq 0 ]; then
  apt-get update > /dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y ffmpeg php8.2-uploadprogress
  DEBIAN_FRONTEND=noninteractive apt-get remove -y apache2 apache2-bin apache2-data apache2-utils file libapache2-mod-php libapache2-mod-php8.3 libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap libjansson4 liblua5.3-0 libmagic-mgc libmagic1 mailcap mime-support php8.3-cli php8.3-common php8.3-opcache php8.3-readline php8.4-cli php8.4-common php8.4-opcache php8.4-phpdbg php8.4-readline php8.4-uploadprogress
fi

date +"@ %Y-%m-%d %H:%M:%S %z"
