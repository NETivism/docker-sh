#!/bin/bash

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} -d DOMAIN -w PORT_WWW -m PORT_DB -r hub/repository [-v MOUNT] [-u DBNAME] [-p PASSWD]
    -d DOMAIN   Domain name for this site, will also assign to container name
    -n SITE_NAME Site name of this container
    -l SITE_MAIL Site mail notification when this done.
    -w PORT_WWW Parent port for mapping to Apache in container
    -m PORT_DB  Parent port for mapping to MySQL in container
    -r REPOS    Registered repository on docker hub
    -v MOUNT    Additional dir mounting to container
    -u DBNAME   Database and mysql user name when first initialize
    -p PASSWD   Optional. Setup password when initialize mysql database
    -s SCRIPT   Optional. Initialize script when docker run. Default is "init.sh" (container/init.sh)
    -t TYPE     Optional. Default for small sites, you can choose bigger for: [default|medium|large]
    -f FORCE    Optional. Force start again even exists. Will kill docker and restart again 
    -D DEBUG    Optional, will enable debug mode, port will not bind to 127.0.0.1

Help: 
  Container started, this will exec and enter docker base on -d
  Container stopped, this will start again base on -d
    docker-start.sh -d test.com    

  Container not exists, this will install(docker run) container:
    docker-start.sh -d test.com -w 10001 -m 30001 -r hub/repository

  Add database name and password:
    docker-start.sh -d test.com -w 10001 -m 30001 -r hub/repository -u demotestcom -p 123456

  Mount additional dir into container /mnt:
    docker-start.sh -d test.com -w 10001 -m 30001 -r hub/repository -v /mnt/drupal-7.37

  Force start and with pre-defined initial script:
    docker-start.sh -d test.com -w 10001 -m 30001 -r hub/repository -v /mnt/drupal-7.37 -s neticrm-7.sh -f

  Start and with pre-defined script for larger site:
    docker-start.sh -d test.com -w 10001 -m 30001 -r hub/repository -v /mnt/drupal-7.37 -s neticrm-7.sh -t large

  Debug mode:
    docker-start.sh -d test.com -w 10001 -m 30001 -r hub/repository -v /mnt/drupal-7.37 -D
EOF
}

# Initialize vars
HOSTIP=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')
HOST_MAIL="mis@netivism.com.tw"
REALPATH=`realpath $0`
WORKDIR=`dirname $REALPATH`

# getopts specific
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "hDd:w:m:r:v:u:p:s:t:n:l:f" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        D)
            DEBUG="true"
            ;;
        d)  DOMAIN=$OPTARG
            ;;
        w)  PORT_WWW=$OPTARG
            ;;
        m)  PORT_DB=$OPTARG
            ;;
        r)  REPOS=$OPTARG
            ;;
        v)  MOUNT=$OPTARG
            ;;
        u)  DBNAME=$OPTARG
            ;;
        p)  PASSWD=$OPTARG
            ;;
        s)  SCRIPT=$OPTARG
            ;;
        t)  TYPE=$OPTARG
            ;;
        n)  SITE_NAME=$OPTARG
            ;;
        l)  SITE_MAIL=$OPTARG
            ;;
        f)  FORCE="true"
            ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

# before attach / restart, we need at least docker name
if [ -z "$DOMAIN" ]; then
  echo -e "\e[1;31m[Required]\e[0m -d option is required to restart / attach docker. Use -h for help."
  exit 1
fi

STARTED=`docker ps --format '{{.Names}}'| grep "^$DOMAIN"`
STOPPED=`docker ps -a -f exited=0 --format='{{.Names}}' | grep "^$DOMAIN"`
if [ -n "$FORCE" ] && [ -n "$PORT_DB" ] && [ -n "$PORT_WWW" ] && [ -n "$REPOS" ]; then
  echo "Stop and kill exists container .. then start again"
  if [ -n "$STARTED" ]; then
    docker exec -it $DOMAIN supervisorctl stop all && docker stop $DOMAIN && docker rm $DOMAIN
    STARTED=""
    STOPPED=""
  fi
  if [ -n "$STOPPED" ]; then
    STARTED=""
    STOPPED=""
    docker rm $DOMAIN
  fi
fi

if [ -n "$STARTED" ]; then
  echo "Container exists... $DOMAIN"
fi

if [ -n "$STOPPED" ]; then
  echo "Docker start ... $DOMAIN"
  docker start $DOMAIN
  exit
fi

## before docker run, we should check all options exists
if [ -z "$PORT_DB" ] || [ -z "$PORT_WWW" ] || [ -z "$REPOS" ]; then
  echo -e "\e[1;31m[Required]\e[0m -d, -w, -m, -r options are required when processing docker run. Use -h for help."
  exit 1
fi

if [ -z "$STARTED" ] && [ -z "$STOPPED" ]; then
  echo "Docker run ... $DOMAIN"
  if [ -z "$DBNAME" ]; then
    DB=$(echo $DOMAIN | sed 's/[^a-zA-Z0-9]//g' | cut -c 1-10)
  else
    DB=$DBNAME
  fi
  if [ -z "$PASSWD" ]; then
    PASSWD=`tr -dc '12345!#qwertQWERTasdfgASDFGzxcvbZXCVB' < /dev/urandom | head -c10; echo ""`
  fi
  if [ ! -d /var/mysql/sites/$DOMAIN/mysql ]; then
    echo "First time init DB:"
    echo "DB_NAME: $DB"
    echo "DB_PASS: $PASSWD"
  else
    echo "Your database already exists!"
  fi

  if [ ! "$MOUNT" ]; then
    MOUNT=""
  else
    DEST="/mnt/$( basename "$MOUNT" )"
    MOUNT="-v $MOUNT:$DEST"
  fi

  # make sure we have log dir
  mkdir -p /var/www/sites/$DOMAIN/log/supervisor
  mkdir -p /var/mysql/sites/$DOMAIN
  if [ -n "$SCRIPT" ]; then
    if [ -f "$WORKDIR/container/$SCRIPT" ]; then
      INIT_SCRIPT="$WORKDIR/container/$SCRIPT"
    else
      echo -e "\e[1;31m[MISSING]\e[0m -s option can't find your script file. Use -f for help"
      exit 1
    fi
  else
    INIT_SCRIPT="$WORKDIR/container/init.sh"
  fi

  # TYPE
  if [ -f $WORKDIR/mysql/${TYPE}.cnf ]; then
    TYPE_MYSQL="-v $WORKDIR/mysql/${TYPE}.cnf:/etc/mysql/my.cnf"
    if echo "$REPOS" | grep -q "docker-debian-php"; then
      TYPE_MYSQL="-v $WORKDIR/mysql/${TYPE}103.cnf:/etc/mysql/mariadb.cnf"
    fi
    if echo "$REPOS" | grep -q "docker-wheezy-php55:fpm56"; then
      TYPE_MYSQL="-v $WORKDIR/mysql/${TYPE}103.cnf:/etc/mysql/mariadb.cnf"
    fi
    ISMARIADB103=$(docker images --format={{.Repository}}:{{.ID}} | grep netivism/docker-wheezy-php55 | grep "d18d2eb299a2")
    if [ -n "$ISMARIADB103" ]; then
      TYPE_MYSQL="-v $WORKDIR/mysql/${TYPE}103.cnf:/etc/mysql/mariadb.cnf"
    fi
  else
    TYPE_MYSQL="-v $WORKDIR/mysql/my.cnf:/etc/mysql/my.cnf"
    if echo "$REPOS" | grep -q "docker-debian-php"; then
      TYPE_MYSQL="-v $WORKDIR/mysql/my103.cnf:/etc/mysql/mariadb.cnf"
    fi
    if echo "$REPOS" | grep -q "docker-wheezy-php55:fpm56"; then
      TYPE_MYSQL="-v $WORKDIR/mysql/my103.cnf:/etc/mysql/mariadb.cnf"
    fi
    ISMARIADB103=$(docker images --format={{.Repository}}:{{.ID}} | grep netivism/docker-wheezy-php55 | grep "d18d2eb299a2")
    if [ -n "$ISMARIADB103" ]; then
      TYPE_MYSQL="-v $WORKDIR/mysql/${TYPE}103.cnf:/etc/mysql/mariadb.cnf"
    fi
  fi
  if [ -f $WORKDIR/php/${TYPE}55.ini ]; then
    TYPE_PHP="-v $WORKDIR/php/${TYPE}55.ini:/etc/php5/docker_setup.ini"
  else
    TYPE_PHP="" # default alredy include when docker build
  fi
  if [ -f $WORKDIR/php/${TYPE}_opcache_blacklist ]; then
    TYPE_PHP_BLACKLIST="-v $WORKDIR/php/${TYPE}_opcache_blacklist:/etc/php5/opcache_blacklist"
  else
    TYPE_PHP_BLACKLIST="" # default alredy include when docker build
  fi
  if [ -n "$DEBUG" ]; then
    BIND=""
  else
    BIND="127.0.0.1:"
  fi
  if [ -n "$SITE_NAME" ]; then
    SITE_NAME="-e INIT_NAME=${SITE_NAME}"
  else
    SITE_NAME=""
  fi
  if [ -n "$SITE_MAIL" ]; then
    SITE_MAIL="-e INIT_MAIL=${SITE_MAIL}"
  else
    SITE_MAIL=""
  fi

  HOSTNAME=${DOMAIN//\./\-}
  docker run -d --name $DOMAIN \
             --add-host=dockerhost:$HOSTIP \
             -h $HOSTNAME \
             --restart=unless-stopped \
             -p ${BIND}$PORT_WWW:80 \
             -p ${BIND}$PORT_DB:3306 \
             -v /var/www/sites/$DOMAIN:/var/www/html \
             -v /var/mysql/sites/$DOMAIN:/var/lib/mysql \
             -v /etc/localtime:/etc/localtime:ro \
             -v $INIT_SCRIPT:/init.sh \
             $TYPE_MYSQL \
             $TYPE_PHP \
             $TYPE_PHP_BLACKLIST \
             $MOUNT \
             -e INIT_DB=$DB \
             -e INIT_PASSWD=$PASSWD \
             -e INIT_DOMAIN=$DOMAIN \
             $SITE_NAME \
             $SITE_MAIL \
             -e HOST_MAIL=$HOST_MAIL \
             -e "TZ=Asia/Taipei" \
             -w "/var/www/html" \
             -i -t $REPOS
  exit
fi
