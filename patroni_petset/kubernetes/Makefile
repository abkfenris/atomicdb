config:
	kubectl create configmap patroni-pghoard --from-file=pghoard-config/patroni.template.yml --from-file=pghoard-config/pghoard_restore.py --from-file=pghoard-config/pghoard.json --from-file=pghoard-config/recovery.conf
	kubectl create secret generic patroni-wale --from-file=wal-e-config/google-wale.json
	kubectl create -f wale-config.yaml
	kubectl create -f pghoard-secret.yaml

delete:
	kubectl delete -f ps-patroni-ephemeral.yaml -f etcd.yaml
	kubectl delete configmap patroni-pghoard wale-config
	kubectl delete secret patroni-wale
	kubectl delete -f sec-patroni.yaml
	kubectl delete -f pghoard-secret.yaml

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

status:
	kubectl exec patroni-0 -c patroni -- patronictl --config-file /etc/patroni/patroni.yml list patroni01