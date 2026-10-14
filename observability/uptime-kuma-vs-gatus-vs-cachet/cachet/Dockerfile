FROM php:8.3-cli
RUN apt-get update && apt-get install -y --no-install-recommends git unzip libzip-dev libicu-dev libpng-dev libonig-dev \
 && docker-php-ext-install pdo_mysql zip intl gd bcmath pcntl \
 && rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /app
RUN git clone --depth 1 --branch 3.x https://github.com/cachethq/cachet.git . \
 && cp .env.example .env \
 && composer install --no-dev --optimize-autoloader --no-interaction
COPY entrypoint.sh /entrypoint.sh
EXPOSE 8000
CMD ["sh", "/entrypoint.sh"]
