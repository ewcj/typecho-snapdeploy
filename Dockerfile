# Typecho 1.3.0 (stable) on PHP 8.2 + Apache, built for the SnapDeploy free tier.
# The container filesystem is ephemeral: config.inc.php is regenerated from
# environment variables on every start (see entrypoint.sh), and all content
# lives in the external TiDB Cloud database, not on disk.
FROM php:8.2-apache

# ca-certificates: TiDB Cloud requires TLS; its certificates are issued by
# Let's Encrypt, which is in the Debian CA bundle.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates unzip libpng-dev libjpeg-dev libfreetype6-dev libzip-dev libonig-dev libxml2-dev libcurl4-openssl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" pdo_mysql mysqli gd mbstring xml curl zip \
    && a2enmod rewrite \
    && sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    && rm -rf /var/lib/apt/lists/*

# Typecho 1.3.0 stable release (1.3.1 is still a release candidate).
ADD https://github.com/typecho/typecho/releases/download/v1.3.0/typecho.zip /tmp/typecho.zip
RUN unzip -q /tmp/typecho.zip -d /tmp/typecho-src \
    && SRC=$(if [ -d /tmp/typecho-src/build ]; then echo /tmp/typecho-src/build; else echo /tmp/typecho-src; fi) \
    && cp -r "$SRC"/. /var/www/html/ \
    && rm -rf /tmp/typecho.zip /tmp/typecho-src \
    && chown -R www-data:www-data /var/www/html

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
