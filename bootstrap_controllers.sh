sudo mkdir -p /etc/kubernetes/config
wget --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-apiserver \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-controller-manager \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-scheduler \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
sudo mkdir -p /var/lib/kubernetes/
sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
  service-account-key.pem service-account.pem \
  encryption-config.yaml /var/lib/kubernetes/
sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/
sudo cp kube-scheduler.yaml /etc/kubernetes/config/
sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/

sudo cp kube-apiserver.service /etc/systemd/system/kube-apiserver.service
sudo cp kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service
sudo cp kube-scheduler.service /etc/systemd/system/kube-scheduler.service

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

sudo yum update -y
sudo yum install -y epel-release
sudo yum install -y nginx
cat > kubernetes.default.svc.cluster.local.conf <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled
sudo cp kubernetes.default.svc.cluster.local.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local.conf /etc/nginx/sites-enabled/kubernetes.default.svc.cluster.local.conf
sudo systemctl restart nginx
sudo systemctl enable nginx
