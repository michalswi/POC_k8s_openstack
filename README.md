#### K8S deployment

TODO list:
- each kubespray deployment generates the same certificates (kubeconfig - admin.conf)
- rancher, more details [here](./conf/rancher/README.md) - look for TODO
- rancher, persistent volume
- rancher, test rancher clusters in separate network
- kubespray versioning
- the way how to expose services
- monitoring


For k8s deployment we are using **kubespray**.  

\***Terraform**: `v0.9.2`  
**Ansible**: `2.6.3`  
**Python**: `2.7.12`  
**Kubernetes**: `1.10.4`  
**Deployer image**: `ava-docker-local.esisoj70.emea.nsn-net.net/ava/customers/k8s_deployer:0.1.0-1.10.4`  

\*in higher version(s) of terraform there is a problem with **region** for s3 backend

More about **kubespray** you can find here [git](https://github.com/kubernetes-incubator/kubespray) and here [kube](https://kubernetes.io/docs/getting-started-guides/kubespray/).  

**Default deployment contains:**  
- 1 provision instance (**with** FloatingIP)
- 1 lb (**with** FloatingIP)
- 3 masters (**no** FloaingIP)
- 3 workers (**no** FloaingIP)

Default deployment config OS distribution is **Ubuntu** .  
More cluster config details you can find in [kubespray_conf](kubespray_conf/) directory.

**Flow:**  
`PC (deploy master/worker + lb + provision instances) -ssh-> provision instance/jumphost -ssh/kubectl-> master/worker (access only from provision instance)`  

**Files description:**  
- `bucket.tf` - terraform state will be kept on S3,
- `generateTF.yml` - main file with openstack credentials and data to deploy VMs,
- `kubernetes-kp.pem` - pem key file,
- `openstack_cinder` - cinder config use by kubespray during cluster deployment.
  
**Initial steps:**  
Create locally directory where you store all required data needed to deploy VMs on specific openstack cloud/project. Templates you can find [here](./templates/). **Don't** change the name of these files. Additionaly to the same directory you should put **.pem key** needed to ssh to VMs. It shoud look like that:  
```sh
$ tree templates/
templates/
├── bucket.tf
├── generateTF.yml
├── kubernetes-kp.pem
└── openstack_cinder
```

Terraform state will be kept on S3 for that you have to create s3 bucket, for example:
```sh
$ s3cmd -c s3cfg -d mb s3://<bucket-name>
# example, for es-si-os-ohn-65
$ s3cmd -c s3cfg -d mb s3://k8s-dep-ohn65
```

The **previous** stable kubespray version `7d3a6541d77bdcc19720bbd123fef773a5c3f35e`. It's because of [this issue](https://github.com/kubernetes-incubator/kubespray/issues/3082).  
The **latest** stable kubespray version `7d3a6541d77bdcc19720bbd123fef773a5c3f35e`.   
Before run you have to change this version in [deploy.yml](scripts/deploy.yml) file.  

**Docker:**  
```sh
$ export DOCKERIMAGE=ava-docker-local.esisoj70.emea.nsn-net.net/ava/customers/k8s_deployer:0.1.0-1.10.4

# build
$ docker build -t $DOCKERIMAGE --build-arg http_p=$http_proxy .

# test
$ docker run $DOCKERIMAGE

# debug mode
$ docker run -it \
-v <local_director>:/mnt/deploy \
-e https_proxy=$http_proxy -e http_proxy=$http_proxy \
--entrypoint "/bin/bash" $DOCKERIMAGE

# create VMs and deploy k8s cluster
$ docker run -it \
-v <local_director>:/mnt/deploy \
-e https_proxy=$http_proxy -e http_proxy=$http_proxy \
-e ACTION=run \
$DOCKERIMAGE

# delete VMs and k8s cluster
docker run -it \
-v <local_director>:/mnt/deploy \
-e https_proxy=$http_proxy -e http_proxy=$http_proxy \
-e ACTION=del \
$DOCKERIMAGE
```

**TODO:**
- if specific part of code failed how to run it one more time (./run.sh), for now you should run 'debug mode'  


**Cluster setup - manual way description**  

Steps to deploy cluster which are already automated are described [here](https://github.com/kubernetes-incubator/kubespray/blob/master/docs/getting-started.md).  

After successfull nodes deployment log in to **provision** instance. IP in `./ssh-hosts` file, pem key is here `conf/kubernetes-kp.pem`.  

Main directory in **provision** instance is `/deploy`.  

Cinder setup requires setting environment variables in **provision** instance during cluster deployment. For that we will use `conf/openstack_cinder` file. It's described in kubespray repo in file `./roles/kubernetes/node/defaults/main.yml` or directly [here](https://github.com/kubernetes-incubator/kubespray/blob/master/roles/kubernetes/node/defaults/main.yml).  

Cluster deployment will take some time, you can use `screen` for that. 

```sh
$ screen -S deploy

# deploy
# source will set env vars
$ source /deploy/conf/openstack_cinder && ansible-playbook -i /deploy/kubespray/inventory/mycluster/hosts.ini /deploy/kubespray/cluster.yml -vv | tee /deploy/ansible.log

# delete
$ ansible-playbook -i /deploy/kubespray/inventory/mycluster/hosts.ini /deploy/kubespray/remove-node.yml
```

You can verify **cinder** settings in random master/worker:  
```sh
$ grep KUBELET_CLOUDPROVIDER /etc/kubernetes/kubelet.env
...
KUBELET_CLOUDPROVIDER="--cloud-provider=openstack --cloud-config=/etc/kubernetes/cloud_config"

$ cat /etc/kubernetes/cloud_config
```

**kubectl on 'provisioner':**

```sh
$ ls /deploy/kubespray/inventory/mycluster/artifacts/
# master_ip is taken from /etc/hosts
$ echo "alias kubectl='no_proxy=$(grep master-1 /etc/hosts | awk '{print $1}') /deploy/kubespray/inventory/mycluster/artifacts/kubectl --kubeconfig /deploy/kubespray/inventory/mycluster/artifacts/admin.conf'" >> ~/.bashrc
$ source ~/.bashrc
$ kubectl get nodes -o wide
```

#### SERVICES

Deployed with such cluster components:
- flannel,
- kube-dns,
- cinder. 

More cluster config details you can find in [kubespray_conf](kubespray_conf/) directory.

**RANCHER**  

How to deploy rancher is described [here](./conf/rancher/README.md).

**JUPYTER**  

How to deploy jupyter is described [here](./examples/jupyter/README.md).

**ZOOKEEPER**  

More details about deployment you can find [here](https://v1-10.docs.kubernetes.io/docs/tutorials/stateful-application/zookeeper/).  
Instead of `wget` you can get `yml` file from `conf/zookeeper.conf`.   
To create your own ZK docker image you can check `statefulsets/zookeeper` directory for more details.  

Zookeeper instances will be run in **DEFAULT** namespace (could be changed to **ava** in the future) on **WORKER** nodes.  
```sh
# init
# storageclass
$ kubectl create -f conf/storageclass.yml
$ kubectl get sc -o wide
# zookeeper - it will take some time
$ kubectl create -f conf/zookeeper.yml

# check
$ kubectl get pvc
$ kubectl get pods
$ kubectl get svc
$ kubectl exec zk-0 -- cat /opt/zookeeper/conf/zoo.cfg

# test
$ kubectl exec zk-0 zkCli.sh create /hello world
$ kubectl exec zk-1 zkCli.sh get /hello
$ kubectl exec zk-2 zkCli.sh delete /hello

# check zk peer if follower or leader
$ kubectl exec zk-0 zkServer.sh status

# check k8s leader
$ kubectl describe endpoints kube-scheduler -n kube-system

# delete
$ kubectl delete -f conf/zookeeper.yml
# get services and delete if still running
$ kubectl get svc
$ kubectl delete svc <name>
```


**NGINX/LB** in progress..  

```sh
$ cd scripts/
$ sudo ansible-playbook -i ../ssh-hosts nginx.yml -vv
```


**DASHBOARDS** in progress..  

Only for **admin**.  



**KAFKA**   
Use custom kafka image from [wurstmeister](https://github.com/wurstmeister/kafka-docker).  TO BE DONE

```sh
$ kubectl create namespace kafka

$ vim kafka_sc.yml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: kafka-broker
reclaimPolicy: Retain
provisioner: kubernetes.io/cinder
parameters:
  availability: nova

$ kubectl create -f kafka_sc.yml

$ git clone https://github.com/Yolean/kubernetes-kafka
# commit 727899a45ee3965c33a485329e92e3fab347a64c

$ vim kubernetes-kafka/kafka/10broker-config.yml
...
zookeeper.connect=zk-0.zkhs.default.svc.cluster.local:2181,zk-1.zkhs.default.svc.cluster.local:2181,zk-2.zkhs.default.svc.cluster.local:2181

$ vim kubernetes-kafka/kafka/50kafka.yml
...
storage: 10Gi

$ kubectl apply -f ./kubernetes-kafka/kafka
kubectl delete -f ./kubernetes-kafka/kafka
```

**Kafka Manager**
```sh
$ vim kubernetes-kafka/yahoo-kafka-manager/kafka-manager.yml
...
- name: ZK_HOSTS
  value: zk-0.zkhs.default.svc.cluster.local:2181,zk-1.zkhs.default.svc.cluster.local:2181,zk-2.zkhs.default.svc.cluster.local:2181

$ kubectl apply -f ./kubernetes-kafka/yahoo-kafka-manager

# change ClusterIP to LoadBalancer*
$ kubectl -n kafka edit service kafka-manager
```
Add cluster:  
```
Cluster Zookeeper Hosts:
zk-0.zkhs.default.svc.cluster.local:2181,zk-1.zkhs.default.svc.cluster.local:2181,zk-2.zkhs.default.svc.cluster.local:2181

Enable:
Poll consumer information (Not recommended for large # of consumers)
Enable Active OffsetCache (Not recommended for large # of consumers)
```
\* - due to fact that it's not agreed how to expose services

**Tests**

***Option I*** - internal access  
```sh
$ kubectl exec kafka-0 -n kafka -- ls bin/

# log in to container kafka-0 and run
$ kubectl exec -it kafka-0 -n kafka bash

$ JMX_PORT= bin/kafka-topics.sh --list --zookeeper zk-0.zkhs.default.svc.cluster.local:2181
$ JMX_PORT= bin/kafka-topics.sh --create --zookeeper zk-0.zkhs.default.svc.cluster.local:2181 --replication-factor 1 --partitions 1 --topic test_topic
$ JMX_PORT= bin/kafka-console-producer.sh --broker-list kafka-0.broker.kafka.svc.cluster.local:9092 --topic test_topic
> some message 1
> some message 2

# log in to container kafka-1 and run
$ kubectl exec -it kafka-1 -n kafka bash
$ JMX_PORT= bin/kafka-console-consumer.sh --bootstrap-server kafka-0.broker.kafka.svc.cluster.local:9092 --topic test_topic --from-beginning
# -> you should see messages sent from producer
```

***Option II*** - external access NOT COMPLETED  
- [python script](./statefulsets/kafka/kafka_tests.py),
- [some example](https://github.com/Yolean/kubernetes-kafka/tree/master/outside-services).