# Deploying the REDL API

Two different setups, for two different purposes:

- **Local development** → Docker (`docker-compose.yml`). Spins up the whole
  stack (PHP-FPM + Nginx + MySQL) with one command, no PHP/MySQL install
  needed on your laptop.
- **Your distant server** → classic PHP hosting, no Docker. Plain PHP-FPM +
  Nginx/Apache + MySQL, the way most VPS/shared hosting already runs PHP
  apps.

## Local development (Docker)

```bash
cd backend
docker compose up -d --build
```

This builds the app image (PHP 8.3-FPM + Nginx via Supervisor, see
`Dockerfile`), starts MySQL, runs migrations automatically on boot
(`docker/entrypoint.sh`), and serves the API at `http://localhost:8000`.
Config lives in `.env.docker` (already set up, MySQL credentials match the
`mysql` service in `docker-compose.yml`).

Uploaded ride photos persist in the `storage` named volume across restarts.

To follow logs: `docker compose logs -f app`
To stop: `docker compose down` (add `-v` to also wipe the database/photos).

## Distant server (classic PHP, no Docker)

Assumes a VPS (or similar) with PHP 8.3+, Composer, MySQL, and Nginx or
Apache already installed, and SSH access.

### First-time setup

```bash
# On the server
git clone <your-repo-url> /var/www/redl-api
cd /var/www/redl-api/backend

composer install --no-dev --optimize-autoloader

cp .env.production.example .env
php artisan key:generate
# Edit .env: set DB_DATABASE / DB_USERNAME / DB_PASSWORD to your real MySQL
# credentials, and APP_URL to your real domain (e.g. https://api.redl.app)

# Create the MySQL database (adjust user/db names to match .env)
mysql -u root -p -e "CREATE DATABASE redl CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

php artisan migrate --force
php artisan storage:link

# Laravel needs to write to these directories
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

php artisan config:cache
php artisan route:cache
```

Then configure your web server to point at `backend/public` — example
configs are in `deploy/nginx-redl-api.conf.example` and
`deploy/apache-redl-api.conf.example`. Copy the relevant one, adjust the
domain/paths, enable it, and reload the web server. Finish with HTTPS via
Certbot (`certbot --nginx -d api.your-domain.com` or the `--apache`
equivalent) — the Flutter app will be hitting this over the public internet,
so plain HTTP shouldn't be used past initial testing.

### Redeploying after changes

```bash
ssh you@your-server
cd /var/www/redl-api/backend
./deploy/deploy.sh
```

This pulls the latest code, reinstalls dependencies, runs new migrations,
and rebuilds Laravel's caches.

## Pointing the Flutter app at either backend

The app's API base URL is a single build-time constant (see the Flutter
`README.md`). Point it at `http://<your-laptop-LAN-IP>:8000/api` for local
Docker testing on a physical phone on the same Wi-Fi, or at
`https://api.your-domain.com/api` once the distant server is live.
