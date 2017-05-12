config:
	kubectl create configmap patroni-pghoard --from-file=pghoard-config/patroni.template.yml --from-file=pghoard-config/pghoard_restore.py --from-file=pghoard-config/pghoard.json --from-file=pghoard-config/recovery.conf

delete:
	kubectl delete -f pghoard.yaml -f ps-patroni-ephemeral.yaml -f etcd.yaml
	kubectl delete configmap patroni-pghoard
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

all: config pghoard etcd patroni

services:
	kubectl create -f svc-patroni-master
	kubectl create -f svc-patroni-read

e:
	echo \"recovery_target_timeline = \'latest\' \ntrigger_file = \'/pgdata/data/trigger_file\'\nrestore_command = \'pghoard_postgres_command --mode restore --port 16000 --site default --output %p --xlog %f\'\" > /pgdata/data/recovery.conf; 