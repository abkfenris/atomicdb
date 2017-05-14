config:
	kubectl create configmap patroni-pghoard --from-file=pghoard-config/patroni.template.yml --from-file=pghoard-config/pghoard_restore.py --from-file=pghoard-config/pghoard.json --from-file=pghoard-config/recovery.conf
	kubectl create secret generic patroni-wale --from-file=wal-e-config/google-wale.json
	kubectl create -f wale-config.yaml

delete:
	kubectl delete -f ps-patroni-ephemeral.yaml -f etcd.yaml
	kubectl delete configmap patroni-pghoard wale-config
	kubectl delete secret patroni-wale
	kubectl delete -f sec-patroni.yaml

sets: 
	kubectl create -f pghoard.yaml -f etcd.yaml -f ps-patroni-ephemeral.yaml

pghoard:
	kubectl create -f pghoard.yaml

etcd:
	kubectl create -f etcd.yaml

patroni:
	kubectl create -f sec-patroni.yaml
	kubectl create -f ps-patroni-ephemeral.yaml

all: config etcd patroni

services:
	kubectl create -f svc-patroni-master
	kubectl create -f svc-patroni-read

e:
	echo \"recovery_target_timeline = \'latest\' \ntrigger_file = \'/pgdata/data/trigger_file\'\nrestore_command = \'pghoard_postgres_command --mode restore --port 16000 --site default --output %p --xlog %f\'\" > /pgdata/data/recovery.conf; 