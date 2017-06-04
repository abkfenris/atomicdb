config:
	kubectl create -f sec-patroni.yaml
	kubectl create configmap patroni-template --from-file=configs/patroni.template.yml
	kubectl create secret generic patroni-wale --from-file=wal-e-config/google-wale.json
	kubectl create -f wale-config.yaml

delete:
	kubectl delete -f ps-patroni-ephemeral.yaml
	kubectl delete -f etcd-cluster.yaml
	kubectl delete configmap patroni-template wale-config
	kubectl delete secret patroni-wale
	kubectl delete -f sec-patroni.yaml

sets: 
	kubectl create -f pghoard.yaml -f etcd.yaml -f ps-patroni-ephemeral.yaml

pghoard:
	kubectl create -f pghoard.yaml

etcd:
	kubectl create -f etcd.yaml

patroni:
	
	kubectl create -f ps-patroni-ephemeral.yaml

all: etcd-cluster config patroni

services:
	kubectl create -f svc-patroni-master
	kubectl create -f svc-patroni-read

status:
	kubectl exec patroni-0 -c patroni -- patronictl --config-file /etc/patroni/patroni.yml list patroni01

etcd-operator:
	helm install --name etcd-operator stable/etcd-operator

etcd-cluster:
	kubectl apply -f etcd-cluster.yaml

gke-create:
	gcloud beta container clusters create test-cluster --zone us-east1-b --preemptible

gke-delete:
	echo "Do it yourself as there is a confirmation prompt!"
	echo "gcloud container clusters delete test-cluster"

init:
	helm init
	sleep 10
	helm install --name etcd-operator stable/etcd-operator