KUBERNETES_PUBLIC_ADDRESS=192.168.85.101
kubectl get componentstatuses --kubeconfig admin.kubeconfig
curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz
curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version
