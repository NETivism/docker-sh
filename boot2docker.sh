#!/bin/bash
REALPATH=`realpath $0`
WORKDIR=`dirname $REALPATH`
MOUNTDIR=$WORKDIR

if [ -z "$1" ]; then
  echo "Usage:\n  $0 [domain] [email] [script] [repository]"
  echo "\nExample:\n  $0 test.org mail@mail.com neticrm-7.sh netivism/docker-debian-php"
  echo "\nError:"
  echo "  Required domain name."
  exit 1
fi
if [ -z "$2" ]; then
  echo "Usage:\n  $0 [domain] [email] [script] [repository]"
  echo "\nExample:\n  $0 test.org mail@mail.com neticrm-7.sh netivism/docker-debian-php"
  echo "\nError:"
  echo "  Required email"
  exit 1
fi

RESULT=0
if [ ! -d "$MOUNTDIR/neticrm-7" ]; then
  mkdir -p $MOUNTDIR/neticrm-7
  RESULT=$?
fi
if [ ! -d "$MOUNTDIR/www/sites/$1/log/supervisor" ]; then
  mkdir -p $MOUNTDIR/www/sites/$1/log/supervisor
fi
if [ ! -d "$MOUNTDIR/sql/sites/$1" ]; then
  mkdir -p $MOUNTDIR/sql/sites/$1
  RESULT=$?
fi

# pickup port
for WWWPORT in $(seq 30000 1 31000); do
  RESULT=`docker ps -qa | xargs docker inspect --format='{{ .HostConfig.PortBindings }}' | grep "$WWWPORT"`
  if [ -z "$RESULT" ]; then
    break
  fi
done
DBPORT=`expr $WWWPORT + 1`

cd $MOUNTDIR/neticrm-7
if [ ! -d "$MOUNTDIR/neticrm-7/civicrm" ]; then
  git clone -b develop https://github.com/NETivism/netiCRM.git civicrm
  cd civicrm
  git clone -b 7.x-develop https://github.com/NETivism/netiCRM-neticrm neticrm
  git clone -b 7.x-develop https://github.com/NETivism/netiCRM-drupal drupal
  cd ..
  git clone -b 7.x-develop https://git.netivism.com.tw/netivism/neticrmp.git neticrmp
fi

if [ -n "$3" ] && [ -f "$WORKDIR/container/$3" ]; then
  SCRIPT="$WORKDIR/container/$3"
else
  SCRIPT="$WORKDIR/container/neticrm-7.sh"
fi
REPOS="netivism/docker-wheezy-php55"
if [ -n "$4" ]; then
  REPOS=$4
fi

if [ -n "$WWWPORT" ] && [ -n "$DBPORT" ]; then
  HOSTNAME="${1//\./-}"
  HOSTIP=`ip route | grep "docker0" | xargs -n 1 | grep -oE "^172\.17\.[0-9]{1,3}\.[0-9]{1,3}$"`
  docker run -d --name $1 \
  --add-host=dockerhost:$HOSTIP \
  --restart=unless-stopped \
  -h $HOSTNAME \
  -p $WWWPORT:80 \
  -p $DBPORT:3306 \
  -v $MOUNTDIR/www/sites/$1:/var/www/html \
  -v $MOUNTDIR/sql/sites/$1:/var/lib/mysql \
  -v /etc/localtime:/etc/localtime:ro \
  -v $SCRIPT:/init.sh \
  -v $MOUNTDIR/neticrm-7:/mnt/neticrm-7 \
  -e INIT_DB=develop \
  -e INIT_PASSWD=123456 \
  -e INIT_DOMAIN=$1 \
  -e INIT_NAME=develop \
  -e INIT_MAIL=$2 \
  -e HOST_MAIL=mis@netivism.com.tw \
  -e "TZ=Asia/Taipei" \
  -w "/var/www/html" \
  -i -t $REPOS

  docker cp $WORKDIR/mysql/my.cnf $1:/etc/mysql/my.cnf
  docker ps -f "name=$1"
  echo "$1 is listen on port $WWWPORT"
fi
