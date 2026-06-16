# syntax=docker/dockerfile:1

# Beide ARGs muessen VOR dem ersten FROM stehen, sonst sind sie nur in der
# Stage sichtbar, in der sie deklariert wurden (ARG-Scoping in Multi-Stage-Builds).
ARG PHP_VERSION=8.3
ARG COMPOSER_VERSION=2

# Eigene Stage fuer Composer: BuildKit kann ARG-Werte nicht direkt in
# "COPY --from=composer:${COMPOSER_VERSION}" expandieren. Stattdessen wird
# eine benannte Stage per FROM mit dem ARG erzeugt und ueber den Stage-Namen
# kopiert (das ist erlaubt, nur die direkte Image-Referenz nicht).
FROM composer:${COMPOSER_VERSION} AS composer_stage

FROM php:${PHP_VERSION}-fpm-alpine

# Composer aus der composer_stage kopieren, statt einen separaten Composer-Container
# mit potenziell anderer PHP-Version zu nutzen. So passt die Plattform, gegen die Composer
# Pakete aufloest, immer exakt zur tatsaechlichen Laufzeit-PHP-Version (PHP_VERSION).
COPY --from=composer_stage /usr/bin/composer /usr/bin/composer

RUN set -eux; \
    apk add --no-cache \
        ca-certificates \
        icu-dev \
        oniguruma-dev \
        libxml2-dev \
        libzip-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        curl-dev \
        linux-headers \
        $PHPIZE_DEPS; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" \
        pdo_mysql \
        intl \
        mbstring \
        xml \
        zip \
        gd \
        opcache \
        curl; \
    pecl install xdebug; \
    docker-php-ext-enable opcache; \
    rm -rf /tmp/pear; \
    apk del --no-cache $PHPIZE_DEPS

COPY conf.d/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini.disabled
COPY entrypoint.sh /usr/local/bin/devstack-entrypoint
RUN chmod +x /usr/local/bin/devstack-entrypoint

RUN set -eux; \
    { \
        echo 'opcache.enable=1'; \
        echo 'opcache.enable_cli=1'; \
        echo 'opcache.validate_timestamps=1'; \
        echo 'opcache.revalidate_freq=0'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=10000'; \
    } > /usr/local/etc/php/conf.d/opcache-dev.ini

WORKDIR /var/www/html

ENTRYPOINT ["devstack-entrypoint"]
CMD ["php-fpm"]
