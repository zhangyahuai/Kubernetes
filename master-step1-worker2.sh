#!/bin/bash

MASTER_IP=192.168.205.10
WORKER1_IP=192.168.205.12

MASTER_HOSTNAME=centos01
WORKER1_HOSTNAME=centos03


scp ca* root@${WORKER1_IP}:

  cat > worker-2-csr.json <<EOF
{
  "CN": "system:node:${WORKER1_HOSTNAME}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:nodes",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${WORKER1_HOSTNAME},${WORKER1_IP} \
  -profile=kubernetes \
  worker-2-csr.json | cfssljson -bare worker-2

scp worker-2* root@${WORKER1_IP}:

scp kube-proxy* root@${WORKER1_IP}:

kubectl config set-cluster kubernetes-training \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${MASTER_IP}:6443 \
  --kubeconfig=worker-2.kubeconfig

kubectl config set-credentials system:node:worker-2 \
  --client-certificate=worker-2.pem \
  --client-key=worker-2-key.pem \
  --embed-certs=true \
  --kubeconfig=worker-2.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:node:worker-2 \
  --kubeconfig=worker-2.kubeconfig

kubectl config use-context default --kubeconfig=worker-2.kubeconfig

scp worker-2.kubeconfig root@${WORKER1_IP}:

scp kube-proxy.kubeconfig root@${WORKER1_IP}: