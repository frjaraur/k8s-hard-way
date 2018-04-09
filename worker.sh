#!/bin/sh
k8s_release_url=$1
POD_CIDR=$2
ETCD_SERVER=$2

default_k8s_release_url="https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64"
k8s_release_url=${k8s_release_url:=${default_k8s_release_url}}

default_etcd_server="10.10.10.11"
ETCD_SERVER=${ETCD_SERVER:=${default_etcd_server}}

default_pod_cidr="10.200.100.0/24"
POD_CIDR=${POD_CIDR:=${default_pod_cidr}}

KUBE_API_SERVER_IP="$(hostname -i)"

HOSTNAME="$(hostname)"

echo "Installing Worker"

sudo apt-get -qq install socat

echo "K8s Master Binaries URL ${k8s_release_url}"
[ ! -f /usr/local/bin/kube-proxy ] && curl -o /usr/local/bin/kube-proxy -sSL ${k8s_release_url}/kube-proxy
[ ! -f /usr/local/bin/kubelet ] && curl -o /usr/local/bin/kubelet -sSL ${k8s_release_url}/kubelet
[ ! -f /usr/local/bin/kubectl ] && curl -o /usr/local/bin/kubectl -sSL ${k8s_release_url}/kubectl


chmod +x /usr/local/bin/kube*
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

[ ! -d /opt/cni/bin/ ] && \
curl -o /tmp/cni-plugins-amd64-v0.6.0.tgz \
 -sSL https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
&& tar -xvf /tmp/cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/

[ ! -f /usr/local/bin/cri-containerd ] \
&& curl -o /tmp/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz \
 -sSL https://github.com/containerd/cri-containerd/releases/download/v1.0.0-beta.1/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz \
&& tar -xvf /tmp/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz -C /




cat > 10-bridge.conf <<EOF
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF


cat > 99-loopback.conf <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF


mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/


mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/

mv ca.pem /var/lib/kubernetes/

cat > /etc/systemd/system/kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=cri-containerd.service
Requires=cri-containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --anonymous-auth=false \\
  --authorization-mode=Webhook \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --cloud-provider= \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/cri-containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --pod-cidr=${POD_CIDR} \\
  --register-node=true \\
  --runtime-request-timeout=15m \\
  --tls-cert-file=/var/lib/kubelet/${HOSTNAME}.pem \\
  --tls-private-key-file=/var/lib/kubelet/${HOSTNAME}-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF



mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=10.200.0.0/16 \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF




systemctl daemon-reload
systemctl enable containerd cri-containerd kubelet kube-proxy
systemctl start containerd cri-containerd kubelet kube-proxy
