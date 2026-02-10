FROM php:8.3-fpm-alpine

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
