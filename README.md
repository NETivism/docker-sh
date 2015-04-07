# Directory Structure

```
| apache
| - default - default config for apache+php, will link when docker run
| container
| - init.sh - exec when docker run, init directory, db etc. Start apache mysql service.
| php
| - default52 - php 5.2 version specific config file, will link when docker run
| *.sh - scripts for handling docker
```

# docker-start.sh

```
Help: 
  Container started, this will exec and enter docker base on -d
  Container stopped, this will start again base on -d
    docker-start.sh -d test.com    

  Container not exists, this will install(docker run) container
    docker-start.sh -d test.com -w 12345 -m 23456 -r docker-owner/docker-repository

  Add database password at the end
    docker-start.sh -d test.com -w 12345 -m 23456 -r docker-owner/docker-repository -p 12345

Usage: docker-start.sh -d DOMAIN -w PORT_WWW -m PORT_DB -r Docker-owner/Docker-repository [-p PASSWD] 
    -d DOMAIN   Domain name for this site, will also assign to container name
    -w PORT_WWW Parent port for mapping to Apache in container
    -m PORT_DB  Parent port for mapping to MySQL in container
    -r REPOS    Registered repository on docker hub
    -p PASSWD   Optional. Setup password when initialize mysql database
```
