#!/usr/bin/env bash

set -e

WORKDIR=$(pwd)

# copy files needed for deployment where './' is '/k8s_kubespray'
cp /mnt/deploy/bucket.tf ./
cp /mnt/deploy/generateTF.yml ./
cp /mnt/deploy/openstack_cinder ./conf/
cp /mnt/deploy/*.pem ./conf/
chmod 600 ./conf/*.pem

ansible-playbook  -i "localhost" generateTF.yml

# to keep remote state with s3 
terraform init
terraform plan
terraform apply | tee ./apply.log

{ echo -e [nodes];cat k-hosts | awk '{print $1}'; } > ssh-k-hosts

provisionerIP=$(grep -A1 "provisioner" $WORKDIR/ssh-hosts | tail -n 1)
lbIP=$(grep -A1 "lb" $WORKDIR/ssh-hosts | tail -n 1)

# provision/jumphost VM need some time to be accessible thru 22
set +e
count=0
while [ $count -lt 5 ]; do
    echo -e '\035\nquit' | telnet $provisionerIP 22
    if [ $? -eq 1 ]; then
        echo -e "No access to jumphost..\n"
        sleep 10
        let count=count+1
    else
        break
    fi
done
if [ $count == 2 ]; then
  echo -e "No connection to jumphost. Try one more time..\n"
  exit
fi
set -e

cd scripts/
ansible-playbook -i ../ssh-hosts init.yml -vv
ansible-playbook -i ../ssh-hosts deploy.yml -vv

# deploy kubespray
sleep 10
kubesprayDeployCommand='source /deploy/conf/openstack_cinder && \
ansible-playbook -i /deploy/kubespray/inventory/mycluster/hosts.ini \
/deploy/kubespray/cluster.yml -vv'
kubesprayDeleteCommand='ansible-playbook -i \
/deploy/kubespray/inventory/mycluster/hosts.ini \
/deploy/kubespray/remove-node.yml'
ssh -o StrictHostKeyChecking=no -i $WORKDIR/conf/*.pem root@$provisionerIP "${kubesprayDeployCommand}"

# jumphost and loadbalancer
echo -e "-------------------\nJumphost: ${provisionerIP}\nLoadbalancer: ${lbIP}\n-------------------"