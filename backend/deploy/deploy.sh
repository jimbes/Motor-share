#!/usr/bin/env bash
# Redeploy script for the REDL API on a classic (non-Docker) server.
# Run this from the project root on the server, over SSH, after the initial
# setup described in DEPLOY.md has been done once.
set -euo pipefail

echo "Pulling latest code..."
git pull origin main

echo "Installing PHP dependencies..."
composer install --no-dev --optimize-autoloader

echo "Running migrations..."
php artisan migrate --force

echo "Rebuilding caches..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "Done. REDL API redeployed."
