function join_by { local IFS="$1"; shift; echo "$*"; }
#4-client-server-certificates ***********************************************
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "TH",
      "L": "Nonthaburi",
      "ST": "Nonthaburi",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way"
    }
  ]
}
EOF

xs=$(cat inventory.csv | cut -d, -f3)
is=$(cat inventory.csv | cut -d, -f2)
is_etcds=$(cat inventory.csv | cut -d, -f2 | awk '{ print "https://" $0 ":2379" }')
joinedExternalIPs=$(join_by , $xs)
joinedInternalIPs=$(join_by , $is)
joinedEtcdIPs=$(join_by , $is_etcds)
NUM_API_SERVER=4
echo $joinedExternalIPs
echo $joinedEtcdIPs
cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -hostname=${joinedExternalIPs},${joinedInternalIPs},127.0.0.1,10.32.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
#*****************************************************************************
##08-bootstrapping-kubernetes-controllers ************************************
while IFS=, read -r Node InternalIp ExternalIp IsController IsWorker
do
  if [ $IsController = true ] ; then
    cat > controllers/${Node}.kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${InternalIp} \\
  --allow-privileged=true \\
  --apiserver-count=$NUM_API_SERVER \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=$joinedEtcdIPs \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  fi
done < inventory.csv
#*****************************************************************************
