#!/bin/bash
set -e

#show all commands
if [ "$VERBOSE_ENTRYPOINT" ]; then
	set -x 
fi

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

recovery_conf () {
	echo 'Writing recovery.conf'
	#  --prefetch=16
	cat > ${PG_DATA}/recovery.conf <<-EOCONF
		restore_command = 'envdir $WALE_ENVDIR wal-e wal-fetch %f %p'
		recovery_target_timeline = latest
		recovery_target_action = 'pause'
	EOCONF
}

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

elif [ "$1" = 'backup' ]; then

	# need to do something like
	# gosu postgres psql -h localhost -c 'SELECT pg_is_in_recovery();'
	# and see if this is currently the leader
	#
	# wal-e cannot take a basebackup from a follower
	#
	# probably should setup cron on all pods
	# and have an additional script that cron calls and does the check

	
	echo 'Setting up backup cron job'

	if [ "$WALE_CRON_TIMING" ]; then
		echo 'Setting cron timing to $WALE_CRON_TIMING '
		cat >  /etc/cron.d/wal-e-cron <<-EOCRON
			PATH=/bin:/usr/bin:/usr/local/bin
			PG_DATA=$PG_DATA
			WALE_ENVDIR=$WALE_ENVDIR
			$WALE_CRON_TIMING postgres /scripts/backup.sh  >> /var/log/cron.log 2>&1
		EOCRON
	else
		echo "Defaulting cron timing to backup at 1 am"
		cat >  /etc/cron.d/wal-e-cron <<-EOCRON
			PATH=/bin:/usr/bin:/usr/local/bin
			PG_DATA=$PG_DATA
			WALE_ENVDIR=$WALE_ENVDIR
			0 1 * * * postgres /scripts/backup.sh  >> /var/log/cron.log 2>&1
		EOCRON
	fi
	
	cat /etc/cron.d/wal-e-cron
	chmod 0644 /etc/cron.d/wal-e-cron
	touch /var/log/cron.log
	chown postgres:postgres /var/log/cron.log

	cron && tail -f /var/log/cron.log


elif [ "$1" = 'restore' ]; then
	echo 'Attempting to restore basebackup with WAL-E'
	if [ "$IGNORE_WAL_BASEBACKUP_MISSING" ]; then
		echo 'IGNORE_WAL_BASEBACKUP_MISSING found, checking for basebackup but will continue if missing'
		echo 'Remove IGNORE_WAL_BASEBACKUP_MISSING to require restore to be successful'
		gosu postgres envdir $WALE_ENVDIR wal-e backup-fetch $PG_DATA LATEST || true
	else
		gosu postgres envdir $WALE_ENVDIR wal-e backup-fetch $PG_DATA LATEST
	fi
	
	if [[ -f ${PG_DATA}/postgresql.conf.backup ]]; then
		echo 'Wal-e base restore completed. Attmepting WAL restore'
		
		recovery_conf

		echo 'recovery.conf file written'

		chown postgres:postgres ${PG_DATA}/recovery.conf
		ls $PG_DATA


		#echo '\n # postgresql.auto.conf \n'
		#cat ${PG_DATA}/postgresql.auto.conf

		#echo '\n # postgresql.base.conf \n'
		#cat ${PG_DATA}/postgresql.base.conf

		#echo '\n # postgresql.base.conf.backup \n'
		#cat ${PG_DATA}/postgresql.base.conf.backup

		#echo '\n # postgresql.conf.backup \n'
		#cat ${PG_DATA}/postgresql.conf.backup

		#echo '\n\n'

		cp ${PG_DATA}/postgresql.conf.backup ${PG_DATA}/postgresql.conf
		cp ${PG_DATA}/pg_hba.conf.backup ${PG_DATA}/pg_hba.conf

		sed -i.bak '/archive_command/d' ${PG_DATA}/postgresql.conf

		chown postgres:postgres ${PG_DATA}/pg_hba.conf ${PG_DATA}/postgresql.conf


		

		gosu postgres pg_ctl start -D ${PG_DATA}

		while [[ -f ${PG_DATA}/recovery.conf ]]; do
			echo 'Waiting for recovery to complete'
			sleep 5
		done

		echo 'Recovery should be complete. Shutting down postgres'

		gosu postgres pg_ctl stop -m fast -D ${PG_DATA}

		echo 'ready for patroni to take over'
	else
		echo 'No basebackup restored. Letting patroni take over and initialize database'
	fi
	

else
	exec "$@"
fi