FROM php:5.6-apache
MAINTAINER Pierre Cheynier <pierre.cheynier@sfr.com>

ENV PHPIPAM_SOURCE https://github.com/MattParr/phpipam.git
ENV PHPIPAM_VERSION 1.3
ENV WEB_REPO /var/www/html

# Install required deb packages
RUN apt-get update && apt-get -y upgrade && \
    apt-get install -y php-pear php5-curl php5-mysql php5-json php5-gmp php5-mcrypt php5-ldap php5-gd php-net-socket libgmp-dev libmcrypt-dev libpng12-dev libfreetype6-dev libjpeg-dev libpng-dev libldap2-dev git && \
    rm -rf /var/lib/apt/lists/*

# Configure apache and required PHP modules
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install mysqli && \
    docker-php-ext-configure gd --enable-gd-native-ttf --with-freetype-dir=/usr/include/freetype2 --with-png-dir=/usr/include --with-jpeg-dir=/usr/include && \
    docker-php-ext-install gd && \
    docker-php-ext-install sockets && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install gettext && \
    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/x86_64-linux-gnu && \
    docker-php-ext-install gmp && \
    docker-php-ext-install mcrypt && \
    docker-php-ext-install pcntl && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu && \
    docker-php-ext-install ldap && \
    echo ". /etc/environment" >> /etc/apache2/envvars && \
    a2enmod rewrite

COPY php.ini /usr/local/etc/php/

# clone phpipam sources and linked modules to web dir
RUN git clone --depth=1 --recursive --branch ${PHPIPAM_VERSION} ${PHPIPAM_SOURCE} ${WEB_REPO}
RUN ["/bin/bash", "-c", "find ${WEB_REPO} -name '.git' -exec rm -rf {} \;"]

# Use system environment variables into config.php
RUN cp ${WEB_REPO}/config.dist.php ${WEB_REPO}/config.php && \
    sed -i -e "s/\['host'\] = 'localhost'/\['host'\] = 'mysql'/" \
    -e "s/\['user'\] = 'phpipam'/\['user'\] = 'root'/" \
    -e "s/\['pass'\] = 'phpipamadmin'/\['pass'\] = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\")/" \
    ${WEB_REPO}/config.php && \
    sed -i -e "s/\['port'\] = 3306;/\['port'\] = 3306;\n\n\$password_file = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\");\nif(file_exists(\$password_file))\n\$db\['pass'\] = preg_replace(\"\/\\\\s+\/\", \"\", file_get_contents(\$password_file));/" \
    ${WEB_REPO}/config.php

EXPOSE 80

