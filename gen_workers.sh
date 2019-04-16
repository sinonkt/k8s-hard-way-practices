#4-client-server-certificates ***********************************************
FIRST_MASTER_NODE=$(cat inventory.csv | head -n 1 | cut -d, -f3)
EXTERNAL_API_SERVER_LB=$FIRST_MASTER_NODE
KUBERNETES_PUBLIC_ADDRESS=$EXTERNAL_API_SERVER_LB
while IFS=, read -r Node InternalIp ExternalIp IsController IsWorker PodCIDR
do
  if [ $IsWorker = true ] ; then
    cat > workers/$Node-csr.json <<EOF
{
  "CN": "system:node:${Node}",
  "key": {
      "algo": "rsa",
      "size": 2048
  },
  "names": [
      {
          "C": "TH",
          "L": "Nonthaburi",
          "ST": "Nonthaburi",
          "O": "system:nodes",
          "OU": "Kubernetes The Hard Way"
      }
  ]
}
EOF
  cfssl gencert \
    -ca=ca/ca.pem \
    -ca-key=ca/ca-key.pem \
    -config=ca/ca-config.json \
    -hostname=${Node},${ExternalIp},${InternalIp} \
    -profile=kubernetes \
    workers/${Node}-csr.json | cfssljson -bare workers/${Node}
#***********************************************************************
#5-kubernetes-configuration-files **************************************
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=workers/${Node}.kubeconfig

  kubectl config set-credentials system:node:${Node} \
    --client-certificate=workers/${Node}.pem \
    --client-key=workers/${Node}-key.pem \
    --embed-certs=true \
    --kubeconfig=workers/${Node}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${Node} \
    --kubeconfig=workers/${Node}.kubeconfig

  kubectl config set current-context default --kubeconfig=workers/${Node}.kubeconfig
#***********************************************************************
  fi
done < inventory.csv
