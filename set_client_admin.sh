kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca/ca.pem \
  --embed-certs=true \
  --server=https://192.168.85.101:6443

kubectl config set-credentials admin \
  --client-certificate=admin/admin.pem \
  --client-key=admin/admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way
