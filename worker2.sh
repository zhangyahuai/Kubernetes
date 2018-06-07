#!/bin/bash

MASTER_HOSTNAME=centos01
WORKER1_HOSTNAME=centos03

alias cp='cp -f'
alias mv='mv -f'
hostnamectl set-hostname $WORKER1_HOSTNAME

sudo yum install -y yum-utils device-mapper-persistent-data lvm2

sudo yum-config-manager -y --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

sudo yum makecache fast
sudo yum -y install docker-ce

sudo systemctl enable docker
sudo systemctl start docker
#The following commands will install kubelet, kube-proxy.
sudo yum install -y socat

wget --timestamping \
  http://ozqvc9zbu.bkt.clouddn.com/kube-proxy \
  http://ozqvc9zbu.bkt.clouddn.com/kubectl \
  http://ozqvc9zbu.bkt.clouddn.com/kubelet

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

chmod +x kubectl kube-proxy kubelet
sudo mv kubectl kube-proxy kubelet /usr/local/bin/

sudo cp worker-2-key.pem worker-2.pem /var/lib/kubelet/
sudo cp worker-2.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp ca.pem /var/lib/kubernetes/

cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service
[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --anonymous-auth=false \\
  --authorization-mode=Webhook \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --cluster-dns=10.250.0.10 \\
  --cluster-domain=cluster.local \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --require-kubeconfig \\
  --runtime-request-timeout=15m \\
  --pod-infra-container-image=cargo.caicloud.io/caicloud/pause-amd64:3.0 \\
  --tls-cert-file=/var/lib/kubelet/worker-2.pem \\
  --tls-private-key-file=/var/lib/kubelet/worker-2-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Turnning off swap is required by kubelet.
swapoff -a

sudo mv kubelet.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet

sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
sudo cp worker-2-key.pem worker-2.pem /var/lib/kubelet/

cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=10.244.0.0/16 \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

sudo mv kube-proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy

