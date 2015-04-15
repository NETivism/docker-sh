#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  Container started, this will exec and enter docker base on -d
  Container stopped, this will start again base on -d
    docker-start.sh -d test.com    

  Container not exists, this will install(docker run) container
    docker-start.sh -d test.com -w 12345 -m 23456 -r docker-owner/docker-repository

  Add database password at the end
    docker-start.sh -d test.com -w 12345 -m 23456 -r docker-owner/docker-repository -p 12345

Usage: ${0##*/} -d DOMAIN -w PORT_WWW -m PORT_DB -r Docker-owner/Docker-repository [-p PASSWD] 
    -d DOMAIN   Domain name for this site, will also assign to container name
    -w PORT_WWW Parent port for mapping to Apache in container
    -m PORT_DB  Parent port for mapping to MySQL in container
    -r REPOS    Registered repository on docker hub
    -p PASSWD   Optional. Setup password when initialize mysql database
EOF
}

# Initialize vars
HOSTIP=`ip route | awk '/docker0/ { print $NF }'`

# getopts specific
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "hd:p:w:m:r:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        d)  DOMAIN=$OPTARG
            ;;
        p)  PASSWD=$OPTARG
            ;;
        w)  PORT_WWW=$OPTARG
            ;;
        m)  PORT_DB=$OPTARG
            ;;
        r)  REPOS=$OPTARG
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

if [ -n "$STARTED" ]; then
  echo "Docker attach exists container ... $DOMAIN"
  docker exec -it $DOMAIN bash
  exit
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
  DB=$(echo $DOMAIN | sed 's/[^a-zA-Z0-9]//g')
  if [ -z "$PASSWD" ]; then
    echo "Install pwgen ... "
    apt-get install -y pwgen
    PASSWD="$(pwgen -s -1 10)"
  fi
  if [ ! -d /var/mysql/sites/$DOMAIN/mysql ]; then
    echo "First time init DB:"
    echo "DB_NAME: $DB"
    echo "DB_PASS: $PASSWD"
  else
    echo "Your database already exists!"
  fi

  docker run -d --name $DOMAIN \
             --add-host=dockerhost:$HOSTIP \
             -p $PORT_WWW:80 \
             -p 127.0.0.1:$PORT_DB:3306 \
             -v /var/www/sites/$DOMAIN:/var/www/html \
             -v /var/mysql/sites/$DOMAIN:/var/lib/mysql \
             -v /etc/localtime:/etc/localtime:ro \
             -e INIT_DB=$DB \
             -e INIT_PASSWD=$PASSWD \
             -e "TZ=Asia/Taipei" \
             -i -t $REPOS /home/docker/container/init.sh
  exit
fi
