#!/bin/sh

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-d DOMAIN] [-p PORT] [-r Docker-owner/Docker-repository]
    -d DOMAIN   Domain name for this site, also use for container name
    -p PORT     Parent host for mapping to container Apache
    -r REPOS    Registered repository on docker hub
EOF
}

# Initialize vars

# getopts specific
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "hd:p:r:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        d)  DOMAIN=$OPTARG
            ;;
        p)  PORT=$OPTARG
            ;;
        r)  REPOS=$OPTARG
            ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

if [ -z "$DOMAIN" ] || [ -z "$PORT" ]; then
  echo "You need specify all options"
  show_help >&2
  exit 1
fi

STARTED=`docker ps | grep $DOMAIN`
STOPPED=`docker ps -a -f exited=0 | grep $DOMAIN`

if [ -n "$STARTED" ]; then
  echo "Docker attach exists container ... $DOMAIN"
  docker attach $DOMAIN
  exit
fi

if [ -n "$STOPPED" ]; then
  echo "Docker start ... $DOMAIN"
  docker start $DOMAIN
  exit
fi

if [ -z "$STARTED" ] && [ -z "$STOPPED" ]; then
  echo "Docker run ... $DOMAIN"
  DB=$(echo $DOMAIN | sed 's/[^a-zA-Z0-9]//g')
  PW="$(pwgen -s -1 10)"
  if [ ! -d /var/mysql/sites/$DOMAIN/mysql ]; then
    echo "First time init DB, your need to check out [docker logs $DOMAIN] to see password."
  else
    echo "Your database already exists, attach it!"
  fi

  docker run -d --name $DOMAIN \
             -p $PORT:80 \
             -v /var/www/sites/$DOMAIN:/var/www/html \
             -v /var/mysql/sites/$DOMAIN:/var/lib/mysql \
             -e INIT_DB=$DB \
             -e INIT_PASSWD=$PW \
             -i -t $REPOS /home/docker/container/init.sh
  exit
fi
