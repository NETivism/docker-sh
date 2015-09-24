#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  Container started, this will exec and enter docker base on -d
  Container stopped, this will start again base on -d
    docker-start.sh -d test.com    

  Container not exists, this will install(docker run) container:
    docker-start.sh -d test.com -w 12345 -m 23456 -r docker-owner/docker-repository

  Add database name and password:
    docker-start.sh -d test.com -w 12345 -m 23456 -r docker-owner/docker-repository -u demotestcom -p 12345

  Mount additional dir into container /mnt:
    docker-start.sh -d test.com -w 12345 -m 23456 -r docker-owner/docker-repository -v /mnt/drupal-7.37

  Force start:
    docker-start.sh -d test.com -w 12345 -m 23456 -r docker-owner/docker-repository -v /mnt/drupal-7.37 -f

Usage: ${0##*/} -d DOMAIN -w PORT_WWW -m PORT_DB -r Docker-owner/Docker-repository [-v MOUNT] [-u DBNAME] [-p PASSWD]
    -d DOMAIN   Domain name for this site, will also assign to container name
    -w PORT_WWW Parent port for mapping to Apache in container
    -m PORT_DB  Parent port for mapping to MySQL in container
    -r REPOS    Registered repository on docker hub
    -v MOUNT    Additional dir mounting to container
    -u DBNAME   Database and mysql user name when first initialize
    -p PASSWD   Optional. Setup password when initialize mysql database
    -s SCRIPT   Optional. Initialize script when docker run. Default is "init.sh" (container/init.sh)
    -f FORCE    Optional. Force start again even exists. Will kill docker and restart again 
EOF
}

# Initialize vars
HOSTIP=`ip route | awk '/docker0/ { print $NF }'`
REALPATH=`realpath $0`
WORKDIR=`dirname $REALPATH`

# getopts specific
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "hd:w:m:r:v:u:p:s:f" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
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
        f)  FORCE="true"
            ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

# before attach / restart, we need at least docker name
if [ -z "$DOMAIN" ]; then
  echo -e "\e[1;31m[Required]\e[0m -d option is required to restart / attach docker"
  show_help >&2
  exit 1
fi

STARTED=`docker ps | grep $DOMAIN`
STOPPED=`docker ps -a -f exited=0 | grep $DOMAIN`
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
  echo -e "\e[1;31m[Required]\e[0m -d, -w, -m, -r options are required when processing docker run"
  show_help >&2
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
      echo -e "\e[1;31m[MISSING]\e[0m -s option can't find your script file"
      exit 1
    fi
  else
    INIT_SCRIPT="$WORKDIR/container/init.sh"
  fi
  docker run -d --name $DOMAIN \
             --add-host=dockerhost:$HOSTIP \
             --restart=always \
             -p 127.0.0.1:$PORT_WWW:80 \
             -p 127.0.0.1:$PORT_DB:3306 \
             -v /var/www/sites/$DOMAIN:/var/www/html \
             -v /var/mysql/sites/$DOMAIN:/var/lib/mysql \
             -v /etc/localtime:/etc/localtime:ro \
             -v $WORKDIR/mysql/my.cnf:/etc/mysql/my.cnf \
             -v $INIT_SCRIPT:/init.sh \
             $MOUNT \
             -e INIT_DB=$DB \
             -e INIT_PASSWD=$PASSWD \
             -e INIT_DOMAIN=$DOMAIN \
             -e "TZ=Asia/Taipei" \
             -w "/var/www/html" \
             -i -t $REPOS
  exit
fi
