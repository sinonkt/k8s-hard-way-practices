#4-client-server-certificates ***********************************************
FIRST_MASTER_NODE=$(cat inventory.csv | head -n 1 | cut -d, -f3)
EXTERNAL_API_SERVER_LB=$FIRST_MASTER_NODE
KUBERNETES_PUBLIC_ADDRESS=$EXTERNAL_API_SERVER_LB

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "TH",
      "L": "Nonthaburi",
      "ST": "Nonthaburi",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
#****************************************************************************
#5-kubernetes-configuration-files *******************************************
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
#****************************************************************************
