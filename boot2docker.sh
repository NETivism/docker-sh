#!/bin/bash
REALPATH=`realpath $0`
WORKDIR=`dirname $REALPATH`
MOUNTDIR=$WORKDIR

if [ -z "$1" ]; then
  echo -e "Usage:\n  $0 [domain] [email] [script] [repository]"
  echo -e "\nExample:\n  $0 test.org mail@mail.com neticrm-7.sh netivism/docker-debian-php:develop"
  echo -e "\nError:"
  echo -e "  Required domain name."
  exit 1
fi
if [ -z "$2" ]; then
  echo -e "Usage:\n  $0 [domain] [email] [script] [repository]"
  echo -e "\nExample:\n  $0 test.org mail@mail.com neticrm-7.sh netivism/docker-debian-php:develop"
  echo -e "\nError:"
  echo -e "  Required email"
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

# check if remove/rebuild docker container
# should set same port not new one
REBUILD=0
for VAR in "$@"; do
  if [ "$VAR" = "--rebuild" ]; then
    REBUILD=1
  fi
done
if [ "$REBUILD" -eq "1" ]; then
  WPORT=`docker inspect --format='{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' $1`
  if [ -n "$WPORT" ]; then
    WWWPORT=$WPORT
  fi
  MPORT=`docker inspect --format='{{(index (index .NetworkSettings.Ports "3306/tcp") 0).HostPort}}' $1`
  if [ -n "$MPORT" ]; then
    DBPORT=$MPORT
  fi
  if [ -n "$WPORT" ] && [ -n "$MPORT" ]; then
    RESULT=0
    echo -e "Removing container $1 to rebuild new one with exists ports :$WPORT / :$MPORT ..."
    QUIET=`docker rm -f $1`
    RESULT=$?
    sleep 2
    if [ $RESULT -eq 0 ]; then
      echo -e "Success!\n"
    else
      echo -e "Error: could not remove container $1, abort"
      exit 1
    fi
  else
    echo -e "Error: could not find exists container $1. Remove --rebuild parameter and try again"
    echo -e "  $0 $1 $2 $3 $4"
    exit 1
  fi
else
  QUIET=`docker ps -f "name=$1"`
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    echo -e "Error: exists container $1 detected. Add --rebuild parameter and try again"
    echo -e "This commend will update repository to latest verion"
    echo -e "This will not touch your civicrm / neticrm / neticrmp project code"
    echo -e "  $0 $1 $2 $3 $4 --rebuild"
    exit 1
  fi
fi


cd $MOUNTDIR/neticrm-7
if [ ! -d "$MOUNTDIR/neticrm-7/civicrm" ]; then
  RESULT=0
  git clone -b develop https://github.com/NETivism/netiCRM.git civicrm
  cd civicrm
  git clone -b 7.x-develop https://github.com/NETivism/netiCRM-neticrm neticrm
  git clone -b 7.x-develop https://github.com/NETivism/netiCRM-drupal drupal
  cd ..
  git clone -b 7.x-develop https://git.netivism.com.tw/netivism/neticrmp.git neticrmp
  RESULT=$?
  if [ $RESULT -neq 0 ]; then
    echo -e "Error: clone neticrmp project failed, abort."
    exit 1
  fi
fi

if [ -n "$3" ] && [ -f "$WORKDIR/container/$3" ]; then
  SCRIPT="$WORKDIR/container/$3"
else
  SCRIPT="$WORKDIR/container/neticrm-7.sh"
fi
REPOS="netivism/docker-debian-php:develop"
if [ -n "$4" ] && [ "$4" != "--rebuild" ]; then
  REPOS=$4
fi

if [ -n "$WWWPORT" ] && [ -n "$DBPORT" ]; then
  echo -e "Updating to latest repository of $REPOS ..."
  docker pull $REPOS
  echo -e "Success!\n"

  HOSTNAME="${1//\./-}"
  HOSTIP=`ip route | grep "docker0" | xargs -n 1 | grep -oE "^172\.17\.[0-9]{1,3}\.[0-9]{1,3}$"`
  echo -e "Creating container $1 using $REPOS ..."
  sleep 2
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
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    echo -e "Success!\n"
  else
    echo -e "Error: create error, abort"
    exit 1
  fi

  docker cp $WORKDIR/mysql/default103.cnf $1:/etc/mysql/my.cnf
  RESULT=0
  QUIET=`docker ps -f "name=$1"`
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    echo -e "$1 is listen on port $WWWPORT"
  fi
fi
