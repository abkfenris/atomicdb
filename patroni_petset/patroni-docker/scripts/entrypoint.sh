#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

if [ "$1" = 'postgres' -o "$1" = 'patroni' ]; then
	#set some derived variables

	export DOCKER_IP=${POD_IP}
	export HNAME=${POD_NAME}
	export LOOKUP="${POD_NAME}.${POD_GROUP}"
	export NODE=${HNAME//[^a-z0-9]/_}

	#create postgresql directories and set permissions
	mkdir -p /pgdata/data
	mkdir -p /mnt/stats/pgsql-stats/
	chown -R postgres:postgres /pgdata/data
	chmod -R 700 /pgdata/data
	chown -R postgres:postgres /mnt/stats/pgsql-stats
	chmod -R 700 /mnt/stats/pgsql-stats

	# create patroni configuration directory
	mkdir -p /etc/patroni
	chown -R postgres:postgres /etc/patroni

	# create pgpass directory
	mkdir -p /home/postgres
	chown -R postgres:postgres /home/postgres

	#create patroni config
	if [ "$PATRONI_TEMPLATE_PATH" ]; then
		envsubst < $PATRONI_TEMPLATE_PATH > /etc/patroni/patroni.yml

	else
		envsubst < /scripts/patroni.template.yml > /etc/patroni/patroni.yml
	fi
	cat /etc/patroni/patroni.yml

	gosu postgres patroni /etc/patroni/patroni.yml
fi

exec "$@"