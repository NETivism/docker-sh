#!/bin/sh

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-d DOMAIN] [-p PASSWD] [-w PORT_WWW] [-m PORT_DB] [-r Docker-owner/Docker-repository]
    -d DOMAIN   Domain name for this site, will also assign to container name
    -p PASSWD   Setup password when initialize mysql database
    -w PORT_WWW Parent port for mapping to Apache in container
    -m PORT_DB  Parent port for mapping to MySQL in container
    -r REPOS    Registered repository on docker hub
EOF
}

# Initialize vars

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

if [ -z "$DOMAIN" ] || [ -z "$PORT_WWW" ]; then
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
             -p $PORT_WWW:80 \
             -p 127.0.0.1:$PORT_DB:3306 \
             -v /var/www/sites/$DOMAIN:/var/www/html \
             -v /var/mysql/sites/$DOMAIN:/var/lib/mysql \
             -e INIT_DB=$DB \
             -e INIT_PASSWD=$PASSWD \
             -i -t $REPOS /home/docker/container/init.sh
  exit
fi
