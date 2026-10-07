# ==========================================
# Stage 1: Frontend
# ==========================================
FROM node:22.21.1-bookworm AS frontend

WORKDIR /app

COPY package*.json ./

RUN npm install -g npm@10.9.2

RUN npm install

COPY . .

RUN npm run build


# ==========================================
# Stage 2: Composer dependencies
# ==========================================
FROM composer:2.9 AS composer

WORKDIR /app

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts


# ==========================================
# Stage 3: Production
# ==========================================
FROM php:8.3-fpm-bookworm

WORKDIR /var/www/html

# System dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    unzip \
    git \
    curl \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        bcmath \
        intl \
        gd \
        zip \
        exif \
        pcntl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer


# Composer dependencies
COPY --from=composer /app/vendor ./vendor


# Application
COPY . .


# Frontend compiled assets
COPY --from=frontend /app/public/build ./public/build


# Laravel directories
RUN mkdir -p \
        storage/framework/cache \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        bootstrap/cache


# Permissions
RUN chown -R www-data:www-data \
        storage \
        bootstrap/cache \
    && chmod -R 775 \
        storage \
        bootstrap/cache


# Nginx
COPY docker/nginx.conf /etc/nginx/sites-available/default


# Supervisor
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


EXPOSE 80

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
