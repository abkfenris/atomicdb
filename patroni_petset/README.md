# Patroni PetSet Implementation, now with WAL-E!

This is a simplified, demo implementation of HA PostgreSQL using [Patroni](https://github.com/zalando/patroni/) and [Kubernetes PetSet]() with [WAL-E](https://github.com/wal-e/wal-e) for backup and restore.  
It is not a production implementation; for an example of a production implementation, see [Spilo](https://github.com/zalando/spilo/tree/master/postgres-appliance) and the [Helm Chart for Spilo and Patroni](https://github.com/kubernetes/charts/tree/master/incubator/patroni).

## patroni-docker

This is a simple docker container build directory for creating a PostgreSQL instance which uses Patroni for automated replication and HA.  It is the base for the image used in the Kubernetes deployment. 
Included in the build image are PostGIS and WAL-E.

Also included is a separate build just for creating a container with PostgreSQL client tools.

## kubernetes

These are the PetSet kubernetes templates giving an example of how to deploy a cluster based on Patroni.  
Currently, these files deploy emphemeral PostgreSQL, rather than with persistent volumes; look for updates for and example with PVs.

### etcd

First: create an etcd cluster using etcd.yaml or a similar profile.
Another option (that seems to work better) is to use the [CoreOS etcd operator](https://github.com/coreos/etcd-operator#create-and-destroy-an-etcd-cluster) which is [easily deployed with Helm](https://github.com/kubernetes/charts/tree/master/stable/etcd-operator).

```
kubectl create -f etcd.yaml
```

Using etcd operator:

Let's first make our cluster definition.

```yaml
# etcd-cluster.yaml
apiVersion: "etcd.coreos.com/v1beta1"
kind: "Cluster"
metadata:
  name: "etcd-patroni-cluster"
spec:
  size: 3
  version: "3.1.8"
```

```shell
# if helm tiller isn't already deployed to the cluster
helm init

helm install --name etcd-operator stable/etcd-operator

kubectl apply -f etcd-cluster.yaml
```

### config

Now we can create our configs for Patroni and WAL-E.

First, create the secret for the PostgreSQL passwords.  You may want
to replace the actual password; the ones given in the file are "atomic" for all users.

```
kubectl create -f sec-patroni.yaml
```

Now we can create our own patroni.yml template and include it in a config map

```
kubectl create configmap patroni-template --from-file=configs/patroni.template.yml
```

For this example, I'm going to use a Google Storage account, so I'll set up it's needed info.

The first step is to create a [Service Account](https://console.cloud.google.com/iam-admin/serviceaccounts/) that WAL-E will use. Make sure to save the JSON.

I've put it in configs/google-wale.json

We'll create a secret to hold that file for WAL-E to have credentials.

```
kubectl create secret generic patroni-wale --from-file=configs/google-wale.json
```

Now in [Google Storage](https://console.cloud.google.com/storage/browser) create your bucket. Make sure to give your service user permissions to write to the bucket.

Now we need to create a yaml config that contains the info WAL-E uses to run.

```yaml
# wale-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: wale-config
data:
  WALE_GS_PREFIX: gs://my.bucket.com/server
  GOOGLE_APPLICATION_CREDENTIALS: /tmp/wale/google-wale.json
  PGHOST: localhost
```
Save that as `wale-config.yaml` and we can load that config up.

```
kubectl create -f wale-config.yaml
```

### Patroni

Now we can create our patroni cluster.



```
kubectl create -f ps-patroni-ephemeral
```

Finally, create the write and load-balanced read services:

```
kubectl create -f svc-patroni-master.yaml
kubectl create -f svc-patroni-read.yaml
```

These services are currently internal-only using ClusterIP.  You can tinker
with the services to deploy them some other way.
