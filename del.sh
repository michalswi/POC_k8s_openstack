#!/usr/bin/env bash

set -e

# copy files needed for deployment where './' is '/k8s_kubespray'
cp /mnt/deploy/bucket.tf ./
cp /mnt/deploy/generateTF.yml ./

# terraform destroy
ansible-playbook  -i "localhost" generateTF.yml
terraform init
expect scripts/destroy.exp
terraform show
rm -rf apply.log kubespray.tf .terraform/ k-hosts ssh-hosts ssh-k-hosts scripts/hosts.ini scripts/init.retry
echo -e "-------------------\nCluster is destroyed and VMs are removed.\n-------------------"
