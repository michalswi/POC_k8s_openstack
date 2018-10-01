#### K8S deployment

For k8s deployment I am using **kubespray**.  

\***Terraform**: `v0.9.2`  
**Ansible**: `2.6.3`  
**Python**: `2.7.12`  
**Kubernetes**: `1.10.4`  

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
$ export DOCKERIMAGE=<full_name>

# build
$ docker build -t $DOCKERIMAGE .

# test
$ docker run $DOCKERIMAGE

# debug mode
$ docker run -it \
-v <local_director>:/mnt/deploy \
--entrypoint "/bin/bash" $DOCKERIMAGE

# create VMs and deploy k8s cluster
$ docker run -it \
-v <local_director>:/mnt/deploy \
-e ACTION=run \
$DOCKERIMAGE

# delete VMs and k8s cluster
docker run -it \
-v <local_director>:/mnt/deploy \
-e ACTION=del \
$DOCKERIMAGE
```

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

[**RANCHER**](./conf/rancher)

[**JUPYTER**](./examples/jupyter)
