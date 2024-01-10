FROM php:7.2-apache
MAINTAINER Pierre Cheynier <pierre.cheynier@gmail.com>

ENV PHPIPAM_SOURCE https://github.com/phpipam/phpipam/
ARG PHPIPAM_VERSION=1.6.0
ENV PHPMAILER_SOURCE https://github.com/PHPMailer/PHPMailer/
ARG PHPMAILER_VERSION=6.7.1
ENV PHPSAML_SOURCE https://github.com/onelogin/php-saml/
ARG PHPSAML_VERSION=3.4.1
ENV WEB_REPO /var/www/html

# Install required deb packages
RUN sed -i /etc/apt/sources.list -e 's/$/ non-free'/ && \
    apt-get update && apt-get -y upgrade && \
    rm /etc/apt/preferences.d/no-debian-php && \
    apt-get install -y libcurl4-gnutls-dev libgmp-dev libmcrypt-dev libfreetype6-dev libjpeg-dev libpng-dev libldap2-dev libsnmp-dev snmp-mibs-downloader iputils-ping && \
    rm -rf /var/lib/apt/lists/*

# Install required packages and files required for snmp
RUN mkdir -p /var/lib/mibs/ietf && \
    curl -sL https://github.com/cisco/cisco-mibs/raw/main/v2/CISCO-SMI.my -o /var/lib/mibs/ietf/CISCO-SMI.txt && \
    curl -sL https://github.com/cisco/cisco-mibs/raw/main/v2/CISCO-TC.my -o /var/lib/mibs/ietf/CISCO-TC.txt && \
    curl -sL https://github.com/cisco/cisco-mibs/raw/main/v2/CISCO-VTP-MIB.my -o /var/lib/mibs/ietf/CISCO-VTP-MIB.txt && \
    curl -sL https://github.com/cisco/cisco-mibs/raw/main/v2/MPLS-VPN-MIB.my -o /var/lib/mibs/ietf/MPLS-VPN-MIB.txt

# Configure apache and required PHP modules
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install mysqli && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/freetype2 --with-png-dir=/usr/include --with-jpeg-dir=/usr/include && \
    docker-php-ext-install gd && \
    docker-php-ext-install curl && \
    docker-php-ext-install json && \
    docker-php-ext-install snmp && \
    docker-php-ext-install sockets && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install gettext && \
    ln -s /usr/include/$(uname -m)-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/$(uname -m)-linux-gnu && \
    docker-php-ext-install gmp && \
    docker-php-ext-install pcntl && \
    docker-php-ext-configure ldap --with-libdir=lib/$(uname -m)-linux-gnu && \
    docker-php-ext-install ldap && \
    pecl install mcrypt-1.0.1 && \
    docker-php-ext-enable mcrypt && \
    echo ". /etc/environment" >> /etc/apache2/envvars && \
    a2enmod rewrite

COPY php.ini /usr/local/etc/php/

# Copy phpipam sources to web dir
ADD ${PHPIPAM_SOURCE}/archive/v${PHPIPAM_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPIPAM_VERSION}.tar.gz -C ${WEB_REPO}/ --strip-components=1
# Copy referenced submodules into the right directory
ADD ${PHPMAILER_SOURCE}/archive/v${PHPMAILER_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPMAILER_VERSION}.tar.gz -C ${WEB_REPO}/functions/PHPMailer/ --strip-components=1
ADD ${PHPSAML_SOURCE}/archive/refs/tags/${PHPSAML_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/${PHPSAML_VERSION}.tar.gz -C ${WEB_REPO}/functions/php-saml/ --strip-components=1

# Use system environment variables into config.php
ENV PHPIPAM_BASE /
RUN cp ${WEB_REPO}/config.dist.php ${WEB_REPO}/config.php && \
    chown www-data /var/www/html/app/admin/import-export/upload && \
    chown www-data /var/www/html/app/subnets/import-subnet/upload && \
    chown www-data /var/www/html/css/images/logo && \
    echo "\$db['webhost'] = '%';" >> ${WEB_REPO}/config.php && \
    sed -i -e "s/\['host'\] = '127.0.0.1'/\['host'\] = getenv(\"MYSQL_ENV_MYSQL_HOST\") ?: \"mysql\"/" \
    -e "s/\['user'\] = 'phpipam'/\['user'\] = getenv(\"MYSQL_ENV_MYSQL_USER\") ?: \"root\"/" \
    -e "s/\['name'\] = 'phpipam'/\['name'\] = getenv(\"MYSQL_ENV_MYSQL_DB\") ?: \"phpipam\"/" \
    -e "s/\['pass'\] = 'phpipamadmin'/\['pass'\] = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\")/" \
    -e "s/\$trust_x_forwarded_headers = false/\$trust_x_forwarded_headers = boolval(getenv(\"TRUST_X_FORWARDED_HEADERS\")) ?: false/" \
    -e "s/\['port'\] = 3306;/\['port'\] = 3306;\n\n\$password_file = getenv(\"MYSQL_ENV_MYSQL_PASSWORD_FILE\");\nif(file_exists(\$password_file))\n\$db\['pass'\] = preg_replace(\"\/\\\\s+\/\", \"\", file_get_contents(\$password_file));/" \
    -e "s/define('BASE', \"\/\")/define('BASE', getenv(\"PHPIPAM_BASE\"))/" \
    -e "s/\$gmaps_api_key.*/\$gmaps_api_key = getenv(\"GMAPS_API_KEY\") ?: \"\";/" \
    -e "s/\$gmaps_api_geocode_key.*/\$gmaps_api_geocode_key = getenv(\"GMAPS_API_GEOCODE_KEY\") ?: \"\";/" \
    ${WEB_REPO}/config.php

EXPOSE 80
