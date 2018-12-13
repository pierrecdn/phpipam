#!/bin/sh

# copy over the crontab file from the host at /config
CT="/config/crontab"

if [ -f "$CT" ]; then
	/bin/echo "* Copying /config/crontab to /etc/crontab"
	/bin/cp /config/crontab /etc
fi


# wait until MySQL is really available before starting cron and continuing with phpipam startup
maxcounter=60
 
counter=1
while ! mysql --protocol TCP -u"$MYSQL_ENV_MYSQL_USER" -p"$MYSQL_ENV_MYSQL_PASSWORD" -h"$MYSQL_ENV_MYSQL_HOST" -e "show databases;" > /dev/null 2>&1; do
    sleep 1
    counter=`expr $counter + 1`
    if [ $counter -gt $maxcounter ]; then
        >&2 echo "We have been waiting for MySQL too long already; failing."
        exit 1
    fi;
done

/bin/echo "* Starting cron service"
# start the cron service in teh container
/usr/sbin/service cron start
exec /usr/local/bin/docker-php-entrypoint apache2-foreground

