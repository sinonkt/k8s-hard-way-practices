FIRST_MASTER_NODE='tuf1'
while IFS=, read -r Node InternalIp ExternalIp IsController IsWorker PodCIDR
do
  if [ $IsController = true ] && [ $Node = $FIRST_MASTER_NODE ]; then
    scp initialize_RBAC_kubelet.sh vagrant@${Node}:~/
  fi
  if [ $IsController = true ]; then 
    scp ca/ca.pem ca/ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem vagrant@${Node}:~/
    scp admin/admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig vagrant@${Node}:~/
    scp encryption-config.yaml vagrant@${Node}:~/
    scp bootstrap_etcd.sh vagrant@${Node}:~/
    scp systemd/${Node}.etcd.service vagrant@${Node}:~/etcd.service
    scp controllers/${Node}.kube-apiserver.service vagrant@${Node}:~/kube-apiserver.service
    scp kube-controller-manager.service kube-scheduler.yaml kube-scheduler.service vagrant@${Node}:~/
    scp bootstrap_controllers.sh verify_bootstrap_controllers.sh verify_bootstrap_etcd.sh vagrant@${Node}:~/
    scp verify_bootstrap_workers.sh vagrant@${Node}:~/
  fi

  if [ $IsWorker = true ]; then 
    scp ca/ca.pem workers/${Node}-key.pem workers/${Node}.pem vagrant@${Node}:~/
    scp workers/${Node}.kubeconfig kube-proxy.kubeconfig vagrant@${Node}:~/

    cat bootstrap_workers.sh.tmpl | sed -e "s@###HOSTNAME@$Node@g" -e "s@###POD_CIDR@$PodCIDR@g" | tee workers/${Node}_bootstrap_workers.sh
    scp workers/${Node}_bootstrap_workers.sh vagrant@${Node}:~/bootstrap_workers.sh
  fi
done < inventory.csv
