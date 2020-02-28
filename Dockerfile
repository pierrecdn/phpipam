FROM php:7.2-apache

MAINTAINER Richard Kojedzinszky <richard@kojedz.in>

ENV PHPIPAM_SOURCE https://github.com/phpipam/phpipam/
ENV PHPIPAM_VERSION 1.4
ENV PHPMAILER_SOURCE https://github.com/PHPMailer/PHPMailer/
ENV PHPMAILER_VERSION 5.2.21
ENV PHPSAML_SOURCE https://github.com/onelogin/php-saml/
ENV PHPSAML_VERSION 2.10.6
ENV WEB_REPO /var/www/html

# Install required deb packages
RUN sed -i /etc/apt/sources.list -e 's/$/ non-free'/ && \
    apt-get update && apt-get -y upgrade && \
    rm /etc/apt/preferences.d/no-debian-php && \
    apt-get install -y libcurl4-gnutls-dev libgmp-dev libmcrypt-dev libfreetype6-dev libjpeg-dev libpng-dev libldap2-dev libsnmp-dev snmp-mibs-downloader iputils-ping && \
    rm -rf /var/lib/apt/lists/*

# Install required packages and files required for snmp
RUN mkdir -p /var/lib/mibs/ietf && \
    curl -s ftp://ftp.cisco.com/pub/mibs/v2/CISCO-SMI.my -o /var/lib/mibs/ietf/CISCO-SMI.txt && \
    curl -s ftp://ftp.cisco.com/pub/mibs/v2/CISCO-TC.my -o /var/lib/mibs/ietf/CISCO-TC.txt && \
    curl -s ftp://ftp.cisco.com/pub/mibs/v2/CISCO-VTP-MIB.my -o /var/lib/mibs/ietf/CISCO-VTP-MIB.txt && \
    curl -s ftp://ftp.cisco.com/pub/mibs/v2/MPLS-VPN-MIB.my -o /var/lib/mibs/ietf/MPLS-VPN-MIB.txt

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
    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/x86_64-linux-gnu && \
    docker-php-ext-install gmp && \
    docker-php-ext-install pcntl && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu && \
    docker-php-ext-install ldap && \
    pecl install mcrypt-1.0.1 && \
    docker-php-ext-enable mcrypt && \
    echo ". /etc/environment" >> /etc/apache2/envvars && \
    a2enmod rewrite

COPY php.ini /usr/local/etc/php/

# Add phpipam sources to web dir
RUN curl -sL ${PHPIPAM_SOURCE}/archive/${PHPIPAM_VERSION}.tar.gz | tar -xzf - -C ${WEB_REPO}/ --strip-components=1
# Add referenced submodules into the right directory
RUN curl -sL ${PHPMAILER_SOURCE}/archive/v${PHPMAILER_VERSION}.tar.gz | tar -xzf - -C ${WEB_REPO}/functions/PHPMailer/ --strip-components=1
RUN curl -sL ${PHPSAML_SOURCE}/archive/v${PHPSAML_VERSION}.tar.gz | tar -xzf - -C ${WEB_REPO}/functions/php-saml/ --strip-components=1

# Use system environment variables into config.php
ENV PHPIPAM_BASE /
RUN ln -s config.docker.php ${WEB_REPO}/config.php && \
    echo "getenv('IPAM_TIMEZONE') ? date_default_timezone_set(getenv('IPAM_TIMEZONE')) : false;" >> ${WEB_REPO}/config.php && \
    chown www-data /var/www/html/app/admin/import-export/upload && \
    chown www-data /var/www/html/app/subnets/import-subnet/upload && \
    chown www-data /var/www/html/css/images/logo

# Tune for rootless
RUN sed -i -e 's/^Listen.*/Listen 8080/g' /etc/apache2/ports.conf

USER 33

EXPOSE 8080
