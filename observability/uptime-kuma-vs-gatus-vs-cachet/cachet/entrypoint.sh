#!/bin/sh
set -e
cd /app
# artisan serve ignores most container env vars, so write the ones we need into .env
sed -i "s|^APP_KEY=.*|APP_KEY=${APP_KEY}|; s|^APP_URL=.*|APP_URL=${APP_URL}|; s|^APP_ENV=.*|APP_ENV=production|; s|^APP_DEBUG=.*|APP_DEBUG=false|; s|^DB_CONNECTION=.*|DB_CONNECTION=sqlite\nDB_DATABASE=/data/database.sqlite|" .env
touch /data/database.sqlite
php artisan vendor:publish --tag=cachet-assets --force
php artisan migrate --force
exec php artisan serve --host=0.0.0.0 --port=8000
