#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  This will stop and rm container based on -d
    docker-stop.sh -d test.com    

Usage: ${0##*/} -d DOMAIN
    -d DOMAIN   Domain name for this site, will also assign to container name
EOF
}

# getopts specific
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "hd:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        d)  DOMAIN=$OPTARG
            ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

if [ -z "$DOMAIN" ]; then
  echo -e "\e[1;31m[Required]\e[0m -d option is required to restart / attach docker"
  show_help >&2
  exit 1
fi

STARTED=`docker ps | grep $DOMAIN`

if [ -n "$STARTED" ]; then
  echo "Stop container $DOMAIN ... "
  docker exec -it $DOMAIN supervisorctl stop all && docker stop $DOMAIN
  echo "Remove container $DOMAIN ... (data still available)"
  docker rm $DOMAIN
  exit
fi

echo -e "\e[1;31m$DOMAIN not found\e[0m in startted container"
show_help >&2
