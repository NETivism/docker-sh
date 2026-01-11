# netiCRM Self-Host Installation Guide

## Prerequisites
- Docker
- Docker Compose
- netiCRM source code (for Drupal 7 or Drupal 10)


## Manual Installation Steps

### 1. Clone the repository

```sh
git clone -b develop-selfhost git@git.netivism.com.tw:netivism/docker-sh neticrm-develop-selfhost
cd neticrm-develop-selfhost
```

### 2. Prepare netiCRM source code

Make sure you have the netiCRM source code available on your host machine. The path will be mounted into the container.

### 3. Configure environment variables

Copy the example environment file:

```sh
cp example.env .env
```

Edit the `.env` file to configure your installation:

```sh
nano .env
```

#### Required Configuration

**Database Settings**
- `INIT_DB` - Database name (default: neticrmdb)
- `INIT_PASSWD` - Database password (change this!)

**Domain Settings**
- `INIT_DOMAIN` - Your domain or localhost address (e.g., local.dev.localhost or localhost:8080)

**Site Settings**
- `INIT_NAME` - Site name displayed on your netiCRM instance
- `INIT_MAIL` - Site email address
- `HOST_MAIL` - Admin account email (used for Drupal admin account)

**Network Settings**
- `HTTP_PORT` - Port to expose the web server (default: 8080)
- `HTTP_BIND` - IP address to bind to (default: 0.0.0.0, all interfaces)

**netiCRM Path Settings**
- `NETICRM_BASE_PATH` - Absolute path to your netiCRM source code on the host machine
- `NETICRM_VERSION` - Version number (e.g., 7 or 10)

**Initialization Script**
- `INIT_SCRIPT` - Script name for initialization (e.g., neticrm-10 for Drupal 10, neticrm-7 for Drupal 7)

### 4. Start the containers

```sh
docker compose up -d
```

The initialization script will automatically:
- Set up the MySQL database
- Download and install Drupal
- Install required Composer dependencies
- Create symbolic links to your netiCRM source code
- Run the netiCRM installation process

### 5. Monitor the installation

Watch the logs to monitor the installation progress:

```sh
docker compose logs -f php-fpm
```

The installation may take several minutes. Wait for the "Done!" message.

### 6. Access your netiCRM instance

Open your web browser and navigate to:
- `http://localhost:8080` (or the port you configured)
- Or `http://your-domain` if you configured a custom domain

### 7. Login to the system

Generate a one-time login link using drush:

```sh
docker exec -it neticrm-php bash -c 'drush -l $INIT_DOMAIN uli'
```

This will output a URL that you can use to login as the admin user.

The default admin username is `admin` (hardcoded in the initialization script).

### View logs

```sh
# All services
docker compose logs -f

# Specific service
docker compose logs -f php-fpm
docker compose logs -f nginx
```

### Restart services

```sh
docker compose restart
```

### Access the PHP container shell

```sh
docker exec -it neticrm-php bash
```

### Run Drush commands

```sh
# Clear cache
docker exec -it neticrm-php bash -c 'cd /var/www/html && drush cr'

# Check status
docker exec -it neticrm-php bash -c 'cd /var/www/html && drush status'

# Generate one-time login link
docker exec -it neticrm-php bash -c 'drush -l $INIT_DOMAIN uli'
```

## Troubleshooting

### Database connection errors

Make sure your `INIT_DB` and `INIT_PASSWD` are correctly set in `.env` file.

### Port already in use

If port 8080 is already in use, change `HTTP_PORT` in your `.env` file to a different port.

### netiCRM profile not found

Ensure that:
- `NETICRM_BASE_PATH` points to the correct directory containing your netiCRM source code
- The netiCRM source contains the `neticrmp` profile directory
- `NETICRM_VERSION` matches your source code version

### Permission errors

The container runs with specific user permissions. If you encounter permission errors, check the ownership of your mounted volumes.

## Architecture

This setup uses:
- **PHP-FPM container** (neticrm-php): Runs PHP 8.3 with required extensions
- **Nginx container** (neticrm-nginx): Serves as the web server
- **MySQL**: Runs inside the PHP-FPM container (managed by supervisord)
- **Bridge network**: Allows containers to communicate

## Data Persistence

Data is stored in the following locations:
- `./data/www` - Drupal installation files
- `./data/mysql` - MySQL database files

These directories are created automatically when you start the containers.

## For More Information

For more detailed information, refer to the official netiCRM documentation or contact support.
