#!/usr/bin/env bash

if [ -e /entrypoint-hook-start.sh ]; then
	. /entrypoint-hook-start.sh
fi

STARTUP_DEBUG=${STARTUP_DEBUG:='no'}
ENVIRONMENT_REPLACE=${ENVIRONMENT_REPLACE:=''}
CRON_ENABLE=${CRON_ENABLE:='0'}
CRON_COMMANDS=${CRON_COMMANDS:=''}
SUPERVISOR_ENABLE=${SUPERVISOR_ENABLE:=0}
CMD=${CMD:='startup'}

set -e
if [ "$STARTUP_DEBUG" = 'yes' ]; then
    set -x
fi

CMD=$1
if [ "$CMD" != 'startup' ]; then
    exec "$@"
    exit $?
fi

if [ "$CRON_COMMANDS" != '' ]; then
	CRON_ENABLE=1
fi
if [ "$CRON_ENABLE" = '0' ]; then
	rm -f /etc/supervisor/conf.d/crond.conf
else
	SUPERVISOR_ENABLE=$((SUPERVISOR_ENABLE+1))

	if [ "$CRON_COMMANDS" != '' ]; then
		echo $CRON_COMMANDS > /var/spool/cron/crontabs/root
		chown root.crontab /var/spool/cron/crontabs/root
	fi
fi

for f in /docker-entrypoint-init.d/*.sh; do
    . "$f"
done

if [ -e /entrypoint-hook-end.sh ]; then
	. /entrypoint-hook-end.sh
fi


if [ "$ENVIRONMENT_REPLACE" != '' ]; then
	SHELLFORMAT='';
	for varname in `env | cut -d'='  -f 1`; do
		SHELLFORMAT="\$$varname $SHELLFORMAT";
	done
	SHELLFORMAT="'$SHELLFORMAT'"
	
	for envfile in $ENVIRONMENT_REPLACE; do
		echo "Replacing variables in $envfile"
		for configfile in `find $envfile -type f ! -path '*~'`; do
			echo $configfile
			# This will mess files with escaped chars.
			# It will mess: return 200 'User-Agent: *\nDisallow: /';
			#content=`cat $configfile`
			#echo "$content" | envsubst "$SHELLFORMAT" > $configfile
			
			# Temp file is slow but won't mess files with escaped chars.
			cp -f $configfile /dev/shm/envsubst.tmp
			envsubst "$SHELLFORMAT" < /dev/shm/envsubst.tmp > $configfile
		done
	done
	
	rm -f /dev/shm/envsubst.tmp
fi


if [ "$SUPERVISOR_ENABLE" -gt 0 ]; then
  exec supervisord --nodaemon;
else
  exec nginx -g 'daemon off;'
fi
exit $?
