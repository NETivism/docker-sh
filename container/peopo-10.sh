#!/bin/bash
date +"@ %Y-%m-%d %H:%M:%S %z"

# init log directory
if [ ! -d /var/www/html/log ]; then
  mkdir /var/www/html/log
  chown root /var/www/html/log
fi

# install drush
composer require drush/drush

#42010, install ffmpeg
if [ $(dpkg -l | grep "^ii.*ffmpeg" | wc -l) -eq 0 ]; then
  apt-get update > /dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y ffmpeg php8.2-memcache
fi

#upload video support
if [[ "$TranscoderID" == load* ]]; then
  cat > /etc/php/8.2/fpm/conf.d/x_peopo_custom.ini << EOF
upload_max_filesize = 2G
post_max_size = 2G
memory_limit = 512M
opcache.memory_consumption = 512
opcache.jit_buffer_size = 256M
EOF
fi

#allowed more www user visit
if [[ "$TranscoderID" == www* ]]; then
  sed -i 's/pm\.max_children = 8/pm.max_children = 16/g' /etc/php/8.2/fpm/pool.d/www.conf
  cat > /etc/php/8.2/fpm/conf.d/x_peopo_custom.ini << EOF
memory_limit = 512M
opcache.memory_consumption = 512
opcache.jit_buffer_size = 256M
EOF
fi

sleep 3
supervisorctl restart php-fpm

date +"@ %Y-%m-%d %H:%M:%S %z"
