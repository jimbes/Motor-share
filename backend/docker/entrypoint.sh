#!/bin/sh
set -e

cd /var/www/html

echo "Waiting for the database..."
until php artisan db:show > /dev/null 2>&1; do
    sleep 2
done
echo "Database is up."

php artisan migrate --force
php artisan storage:link || true
php artisan config:cache
php artisan route:cache

exec "$@"
