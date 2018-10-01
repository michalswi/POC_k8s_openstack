#!/usr/bin/env python

from string import Template
from shutil import copyfile
import os
import sys

BASE_DIR = '../'

TEMPLATE_FILE = 'hosts_template.txt'
CLUSTER_IPS_FILE = 'k-hosts'
FINAL_HOSTS_FILE = 'hosts.ini'

K_HOSTS = {}
K_HOSTS_ALL = []

def get_k_hosts():
    global K_HOSTS
    with open(BASE_DIR + CLUSTER_IPS_FILE) as kh:
        kh_get = kh.readlines()
    
    for i in kh_get:
        i = i.strip().split()
        K_HOSTS[i[1]] = i[0]

def make_all():
    global K_HOSTS_ALL
    for i in K_HOSTS.items():
        K_HOSTS_ALL.append("{0} ansible_host={1} ip={1}".format(i[0], i[1]))

def get_masters():
    for i in K_HOSTS.keys():
        if 'master' in i:
            yield i

def get_workers():
    for i in K_HOSTS.keys():
        if 'worker' in i:
            yield i

def generate_hosts():
    #overwrite if exists
    copyfile(TEMPLATE_FILE, FINAL_HOSTS_FILE)

    filein = open(FINAL_HOSTS_FILE)
    src = Template(filein.read())
    done_file = {
                'all': '\n'.join(sorted(K_HOSTS_ALL)), \
                'kubemaster': '\n'.join(sorted(get_masters())), \
                'kubenode': '\n'.join(sorted(get_workers())), \
                'etcd': '\n'.join(sorted(get_masters())), \
                'vault': '\n'.join(sorted(get_masters()))
                }
    # it will print and save output to hosts.ini file
    print(src.substitute(done_file))

if __name__ == "__main__":
    if os.path.isfile(BASE_DIR + CLUSTER_IPS_FILE) and os.path.getsize(BASE_DIR + CLUSTER_IPS_FILE) > 0:
        get_k_hosts()
        make_all()
        generate_hosts()
    else:
        sys.exit("Wrong BASE_DIR: {} and/or missing/empty CLUSTER_IPS_FILE: {}".format(BASE_DIR, CLUSTER_IPS_FILE))