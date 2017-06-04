#!/bin/bash
set -e

#show all commands
if [ "$VERBOSE_ENTRYPOINT" ]; then
	set -x 
fi

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

# restore base backup from WAL archive using WAL-E
# Set $IGNORE_WAL_BASEBACKUP_MISSING for first initialization of the database, but then remove it from further runs
base_backup_restore () {
	echo 'Attempting to restore basebackup with WAL-E'
	echo ""
	if [ "$IGNORE_WAL_BASEBACKUP_MISSING" ]; then
		echo 'IGNORE_WAL_BASEBACKUP_MISSING found, checking for basebackup but will continue if missing.'
		echo 'Remove IGNORE_WAL_BASEBACKUP_MISSING to require restore to be successful'
		echo ""
		gosu postgres envdir $WALE_ENVDIR wal-e backup-fetch $PG_DATA LATEST || true
	else
		gosu postgres envdir $WALE_ENVDIR wal-e backup-fetch $PG_DATA LATEST
	fi
}

# After basebackup restore, conf files are in the wrong locations
move_clean_chown_config () {
	echo 'Copying postgresql.conf and pg_hba.conf back to their normal locations, and changing owner.'
	echo ""
	cp ${PG_DATA}/postgresql.conf.backup ${PG_DATA}/postgresql.conf
	cp ${PG_DATA}/pg_hba.conf.backup ${PG_DATA}/pg_hba.conf

	sed -i.bak '/archive_command/d' ${PG_DATA}/postgresql.conf

	chown postgres:postgres ${PG_DATA}/pg_hba.conf ${PG_DATA}/postgresql.conf
}

# configure recovery.conf for WAL restore
recovery_conf () {
	echo 'Writing recovery.conf'
	#  --prefetch=16
	cat > ${PG_DATA}/recovery.conf <<-EOCONF
		restore_command = 'envdir $WALE_ENVDIR wal-e wal-fetch %f %p'
		recovery_target_timeline = latest
		recovery_target_action = 'pause'
	EOCONF
	chown postgres:postgres ${PG_DATA}/recovery.conf
	echo 'recovery.conf file written'
}

# Run postgres until the wal is completely restored
wal_restore () {
	echo 'Starting PostgreSQL server to restore to latest point in WAL'
	echo ""
	gosu postgres pg_ctl start -D ${PG_DATA}

	while [[ -f ${PG_DATA}/recovery.conf ]]; do
		echo 'Waiting for recovery to complete'
		sleep 5
	done

	echo ""
	echo 'Recovery should be complete. Shutting down Postgres'
	echo ""

	gosu postgres pg_ctl stop -m fast -D ${PG_DATA}
	echo 'Postgres server is shut down'
	echo ""
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
	echo "Restoring base backup"
	echo ""
	base_backup_restore

	if [[ -f ${PG_DATA}/postgresql.conf.backup ]]; then
		echo 'Wal-e base restore completed'
		echo ""
		move_clean_chown_config
	fi

	if [[ "$POD_NAME" == *"-0" ]]; then
		echo "First pod in the set, so lets try to restore WAL"
		echo ""
		
		if [[ -f ${PG_DATA}/postgresql.conf.backup ]]; then
			echo 'Attempting WAL restore'
			echo ""
			recovery_conf
			wal_restore

			echo 'Ready for patroni to take over'
		else
			echo 'No basebackup restored. Letting patroni take over and initialize database'
		fi
	else
		echo "Not the first pod, letting patroni have it's way to finish managing restore."
		echo "If pod is behing on WAL, then patroni will use the recover_command after attempting"
		echo "pg_rewind to make sure both leader and replica systems are on the correct timeline."
	fi
	

else
	exec "$@"
fi