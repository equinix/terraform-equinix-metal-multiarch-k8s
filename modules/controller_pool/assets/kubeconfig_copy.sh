#!/bin/bash
/usr/bin/ssh -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$controller "while true; do if ! ( type kubeadm && find /etc/kubernetes/admin.conf -size +1 ) > /dev/null 2>&1 ; then sleep 1; else break; fi; done"
/usr/bin/scp -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/admin.conf $local_path/kubeconfig;

