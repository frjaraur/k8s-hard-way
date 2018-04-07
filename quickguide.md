* Create CA
~~~
cat > ca-config.json <<EOF
{"signing": {"default": {"expiry": "8760h"},"profiles": {"kubernetes": {"usages": ["signing", "key encipherment", "server auth", "client auth"],"expiry": "8760h"}	}}}
EOF
~~~

~~~
cat > ca-csr.json <<EOF
{"CN": "Kubernetes","key": {"algo": "rsa","size": 2048},"names": [{"O": "Kubernetes"}]}
EOF
~~~


~~~
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
~~~

--------------------------

* Create admin certificates, signed by CA

~~~
cat > admin-csr.json <<EOF
{"CN": "admin","key": {"algo": "rsa","size": 2048},"names": [{"O": "system:masters"}]}
EOF
~~~

~~~
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
~~~
--------------------------

* We create certificates for each node, signed by our generated CA

~~~
for host in k8hw2 k8hw3 k8hw4; do 
cat > ${host}-csr.json <<EOF
{"CN": "system:node:${host}","key": {"algo": "rsa","size": 2048},"names": [{"O": "system:nodes"}]}
EOF
done
~~~

~~~
for host in k8hw2 k8hw3 k8hw4; do 
WORKER_HOST_IP_ADDRESSES="$(ssh ${host} hostname -I)";
WORKER_HOST_IP_ADDRESSES="$(echo ${WORKER_HOST_IP_ADDRESSES}|cut -d' ' -f2-|sed -e's/ /,/g')";
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=${host},${WORKER_HOST_IP_ADDRESSES} -profile=kubernetes ${host}-csr.json | cfssljson -bare ${host}
done
~~~

* Quick Verify for Common Names
~~~
openssl x509 -noout -subject -in k8hw2.pem
~~~
----------------------------------

* Create kube-proxy certificate

~~~
cat > kube-proxy-csr.json <<EOF
{"CN": "system:kube-proxy","key": {"algo": "rsa","size": 2048},"names": [{"O": "system:node-proxier"}]}
EOF
~~~

~~~
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
~~~

-----------------------------------

* Create Server API certificate

~~~
cat > kubernetes-csr.json <<EOF
{"CN": "kubernetes","key": {"algo": "rsa","size": 2048},"names": [{"O": "Kubernetes"}]}
EOF
~~~

~~~
KUBERNETES_MASTER_ADDRESSES="$(hostname -I|cut -d' ' -f2-|sed -e's/ /,/g')"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=${KUBERNETES_MASTER_ADDRESSES},127.0.0.1,kubernetes.default -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
~~~

-----------------------------------

* Distribute node certificates y public CA to nodes 

~~~
for host in k8hw2 k8hw3 k8hw4; do scp -q ca.pem ${host}-key.pem ${host}.pem ${host}:~/; done
~~~
----------------------------------

* Create kubeconfig for each node

~~~
KUBERNETES_MASTER_ADDRESS=$(hostname -i)
KUBERNETES_CLUSTER_NAME="k8shw"
for host in k8hw2 k8hw3 k8hw4; do
  kubectl config set-cluster ${KUBERNETES_CLUSTER_NAME} --certificate-authority=ca.pem --embed-certs=true --server=https://${KUBERNETES_MASTER_ADDRESS}:6443 --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} --client-certificate=${host}.pem --client-key=${host}-key.pem --embed-certs=true --kubeconfig=${host}.kubeconfig

  kubectl config set-context default --cluster=${KUBERNETES_CLUSTER_NAME} --user=system:node:${host} --kubeconfig=${host}.kubeconfig

  kubectl config use-context default --kubeconfig=${host}.kubeconfig

done
~~~

----------------------------------

* Create common kube-proxy

~~~
kubectl config set-cluster ${KUBERNETES_CLUSTER_NAME} --certificate-authority=ca.pem --embed-certs=true --server=https://${KUBERNETES_MASTER_ADDRESS}:6443 --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default --cluster=${KUBERNETES_CLUSTER_NAME} --user=kube-proxy --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

~~~
-----------------------------------

* Distribute files

~~~
for host in k8hw2 k8hw3 k8hw4; do scp -q ${host}.kubeconfig kube-proxy.kubeconfig ${host}:~/; done
~~~

-----------------------------------
