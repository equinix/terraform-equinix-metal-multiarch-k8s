#!/bin/bash
/usr/bin/scp -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/admin.conf $local_path/kubeconfig;

