#!/bin/bash

ssh -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_addr "while true; do if ! type kubeadm > /dev/null; then sleep 20; else break; fi; done"
sleep 360
CERT_KEY=$(echo `ssh -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller "kubeadm init phase upload-certs --upload-certs | grep -v upload-certs"` | sed -e 's|(stdin)= ||g')
CA_CERT_HASH=$(echo `ssh -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller "openssl x509 -in /etc/kubernetes/pki/ca.crt -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256"` | sed -e 's|(stdin)= ||g')
ssh -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$node_addr "mkdir -p /etc/kubernetes/pki/etcd" ; \
ssh -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$controller "mkdir -p /etc/kubernetes/pki/etcd; while true; do if [ ! -f /etc/kubernetes/pki/etcd/ca.key ]; then sleep 20; else break; fi; done" ; \
scp -3 -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/pki/ca.crt root@$node_addr:/etc/kubernetes/pki/ca.crt ;\
scp -3 -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/pki/ca.key root@$node_addr:/etc/kubernetes/pki/ca.key ;\
scp -3 -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/pki/sa.key root@$node_addr:/etc/kubernetes/pki/sa.key ;\
scp -3 -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/pki/sa.pub root@$node_addr:/etc/kubernetes/pki/sa.pub ;\
scp -3 -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/pki/front-proxy-ca.crt root@$node_addr:/etc/kubernetes/pki/front-proxy-ca.crt ;\
scp -3 -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/pki/front-proxy-ca.key root@$node_addr:/etc/kubernetes/pki/front-proxy-ca.key ; \
scp -3 -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/pki/etcd/ca.crt root@$node_addr:/etc/kubernetes/pki/etcd/ca.crt ;\
scp -3 -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$controller:/etc/kubernetes/pki/etcd/ca.key root@$node_addr:/etc/kubernetes/pki/etcd/ca.key ;\
echo "waiting..." ; \
sleep 360 ; \
sh -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_addr "kubeadm join $controller:6443 --token $kube_token --control-plane --discovery-token-ca-cert-hash sha256:$CA_CERT_HASH" && \
echo "Control plane node configured: $node_addr"