#K8s-Hard-Way
https://github.com/kelseyhightower/kubernetes-the-hard-way
https://thenewstack.io/7-key-considerations-for-kubernetes-in-production/
Topology: MBPr —| tuf (windows/ubuntu) [bastion] | —> tuf1, tuf2, tuf3, tuf4 (VMs)
*** need to add extra private network for internal communication ***
configure VirtualBox to provision network extra interface
user/password == vagrant:vagrant
super important about proxies: https://kubernetes.io/docs/concepts/cluster-administration/proxies/

Arrival, Summer Wars, Stein Gate

#01-prerequisites
config google cloud engine for provisioning compute infrastructure
which in our case being provisioned by our own laptop virtualbox
we can parallel provisioning via tmux (by enable synchronise-panes)

#02-clients-tools
install cfssl, cfssljson, kubctl
some verification that’s all

#03-compute-resources
provision Virtual Private Cloud network (VPC) create subnet for internal communication which enough to assign to each node of cluster
create subnet 10.240.0.0/24 can hold 254 compute instances.
allowed firewall rules for internal communication across all protocols => [tcp,udp, icmp], sources => 10.240.0.0/24, 10.200.0.0/16
allowed only SSH, ICMP, HTTPS for external
  —allow tcp:22, tcp:6443, icmp \
  —source-ranges 0.0.0.0/0
mentioned an External LB for Kubernetes API server to be exposed
list firewall-rules for verification
***Allocate static IP for attached external load balancer*** reserved via gcloud
spin up VMs via gcloud command line using Ubuntu Server 18.04
kubernetes assigns each node a range of IP address, a CIDR block, so that each pod can have a unique IP address MAXIMUM is no more than 110 pods per node
Maximum Pods per Node
CIDR Range per Node
8
/28
9 to 16
/27
17 to 32
/26
33 to 6443
/25
65 to 110
/24
Internal Subnet 192.168.234.0/24 (ip start from 192.168.234.{101-104})
External Subnet 172.17.8.0/24 ( 254 compute instances) ip start from 172.17.8.{101-104}
tuf CIDR block 10.200.{workerIdx}.0/24 ( 254 /24 subnets)
configuring SSH Access and some verification

Classless Inter-Domain Routing (CIDR /ˈsaɪdər, ˈsɪ-/) is a method for allocating IP addresses and IP routing. The Internet Engineering Task Force introduced CIDR in 

#04-certificate-authority
Provisioning CA and generated TLS Certificates

Root CA of our cluster
***Please keep ca-key.pem file in safe. This key allows to create any kind of certificates within your CA.***
***
cat > my_file.txt << EOF
my content
EOF
*** (ca.pem, ca-key.pem, ca-config.json)
Certificate Authority (CA) : CSR stand for Certificate Signing Request
cfssl print-defaults config > ca-config.json (modified to 5 years expiry & peer auth)
cfssl print-defaults csr > ca-csr.json (correct Org info, also to rsa, keySize to 2048, CN)
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

Common Name (CN) e.g. *.example.com
The fully qualified domain name (FQDN) of your server.

Organization (O)
The legal name of your organization. Do not abbreviate and include any suffixes, such as Inc., Corp., or LLC.

Organizational Unit (OU)
The division of your organization handling the certificate.

City/Locality (L)
The city where your organization is located. This shouldn’t be abbreviated.

State/County/Region (S)
The state/region where your organization is located. This shouldn't be abbreviated.

Country (C)K8s
The two-letter code for the country where your organization is located.

Email Address
An email address used to contact your organization.



Client and Server Certificates:

admin (admin.pem, admin-key.pem)
admin-csr.json (modified CN -> admin, O -> system:masters, OU -> Kubernetes The Hard way)
cfssl gencert -ca=../ca/ca.pem -ca-key=../ca/ca-key.pem -config=../ca/ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

cluster inventory.csv file for easier scripting.

***Node,InternalIp,ExternalIp,IsController,IsWorker*** csv headers
cat > inventory.csv << EOF
tuf1,192.168.234.101,172.17.8.101,true,true
tuf2,192.168.234.102,172.17.8.102,true,true
tuf3,192.168.234.103,172.17.8.103,true,true
tuf4,192.168.234.104,172.17.8.104,true,true
EOF

worker nodes: workers (tuf1.pem, tuf1-key.pem)
loop to generate each worker key and cert according to their ip

Controller Manager Client Cert: (kube-controller-manager-key.pem,kube-controller-manager.pem)

Kube Proxy Client Certificate: (kube-proxy-key.pem,kube-proxy.pem)

Scheduler Client Certificate: (kube-scheduler-key.pem,kube-scheduler.pem)

Service Account Key Pair: (service-account-key.pem, service-account.pem)

Kubernetes API server Certificates: 
modified hostname to 
-hostname=${joinedExternalIPs},127.0.0.1,kubernetes.default \
- hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \

Helpers
*****************************************************************************************
while IFS=, read -r Node InternalIp ExternalIp IsController IsWorker
do 
  …your logic here….
done < test.csv
*****************************************************************************************
function join_by { local IFS= “$1”; shift; echo “$*”; }
join_by , a "b c" d #a,b c,d
join_by / var local tmp #var/local/tmp
join_by , "${FOO[@]}" #a,b,c
*****************************************************************************************

Distribute the Client and Server Certificates
as simple as script state 
  1. worker got their key & cert and also ca cert.
controller got kubernetes-api-server key & cert, service-account key & cert and ca key & cert 


#5-kubernetes-configuration-files
we will generate kubeconfig files for ControllerManager, Kubelet (worker client), kube-proxy, scheduler clients

for HA we need to use external load balancer static ip that fronting kubernetes api server.
but for our cases we need to point to tuf1 for now (172.17.8.101)

I just added more kubeconfig generating logic to existing script.

all of them use client certificate & key to authenticated. there are 3 models of authentication
client cert, token, username password
Workers
workers
kube-proxy

Contoller-Manager
kube-scheduler
admin (user)
kube-controller-manger

FIRST_MASTER_NODE=$(cat inventory.csv | head -n 1 | cut -d, -f3)
EXTERNAL_API_SERVER_LB=$FIRST_MASTER_NODE
KUBERNETES_PUBLIC_ADDRESS=$EXTERNAL_API_SERVER_LB

look at distribute.sh
*** Question: what if master node and minion are the same node how is kubeconfig look like?

#6-data-encryption-keys
encrypt things in cluster
encryption config to provision at controller node
basically we random encryption key create config.yaml distribute to controller node

#7-bootstrapping-etcd
no exceptions! all components are stateless,  cluster state was store to etcd

on every node:

sudo yum install -y wget
wget -q --timestamping "https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz”
tar -xvf etcd-v3.3.9-linux-amd64.tar.gz
sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

#troubleshooting
kubernetes.pem certificate not specify all valid ips boot internal and external should be included

sudo yum install -y wget
wget -q --timestamping https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz
tar -xvf etcd-v3.3.9-linux-amd64.tar.gz
sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
sudo cp etcd.service /etc/systemd/system/etcd.service
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
#08-bootstrapping-kubernetes-controllers
download binaries for each components as following.
kube-apiserver
kube-controller-manager
kube-scheduler
kubctl
chmod +x, mv to /usr/local/bin
configure systemd units for each components.
mv {component}.kubeconfig to /var/lib/kubernetes
start daemons
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manger kube-scheduler
made localhost proxy (start nginx proxy pass healthz api
verification by run 
kubectl get componentstatuses —kubeconfig admin.kubeconfig
curl -H “Host: kubernetes.default.svc.cluster.local” http://127.0.0.1/healthz
initialise RBAC role for kubelete athorization kubeapi-server -> kubelet
create ClusterRole that allow all node/{proxy, stats, log, spec, metrics}
bind ClusterRole kube-apiserver-to-kubernetes to user kubernetes
set up & verify Frontend load balancer.
curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
can’t verify proxy ssl /healthz to https://127.0.0.1:6443/healthz
because SELinux
setsebool -P httpd_can_network_connect 1  # should solve the problem
command to trace SELinux errors 
sudo cat /var/log/audit/audit.log | grep nginx | grep denied
permanent disable selinux at /etc/selinux/config
SELINUX=disabled
https://stackoverflow.com/questions/23948527/13-permission-denied-while-connecting-to-upstreamnginx
#09-boostrapping-kubernetes-workers
install the following components on each worker node
run, gVisor(runsc), container networking plugins, containers, kubelet, kube-proxy

install deps ( socat conntract ipset)
download and install binary
runsc, runs, containerd, crictl, cni-plugins, kubectl, kube-proxy, kubenet, runc, runsc
mv all configurations and systemd units .service files to properly location
start all daemon containerd kubelet kube-proxy
verification

### known errors
forgot/missing set default as current-context for each worker kubeconfig.
poor extracting containerd.tar.gz to /bin/bash -> cause many error from overriding /bin dir.
when rebuild cluster need disabled SELinux and include site-enabled/*.conf at nginx.conf, set net-addapter
need to disabled swap: failed to run Kubelet: Running with swap on is not supported, please disable swap! or set --fail-swap-on flag to false. /proc/swaps contained
swapoff -a
swapon -a

need to reconfigure hostname according to each node name
sudo vim /etc/sysconfig/network -> HOSTNAME=tuf1
sudo vim /etc/hosts
sudo hostnamectl set-hostname tuf1

#10-configuring-kubectl
just create admin remote kubeconfig to access, verify by run some command to cluster

#11-pod-network-routes
now pod scheduled to each node will receive an ip from PodCIDR range but can not communicate with other pods running on different nodes due to missing network

this issue was solved by create next hop for each VPC to be routable all over pod CIDR subnets
tutorials done by create routes on Google cloud engine client api (gcloud command)

"IP-per-pod" networking model

**Failed create pod sandbox: open /run/systemd/resolve/resolv.conf: no such file or directory
need to switch to use systemd-networkd

  135  sudo yum install -y systemd-networkd systemd-resolved
  136  systemctl disable network NetworkManager
  137  sudo systemctl disable network NetworkManager
  138  systemctl enable systemd-networkd systemd-resolved
  139  sudo systemctl enable systemd-networkd systemd-resolved
  140  vim /etc/resolv.conf
  141  mkdir -p /run/systemd/resolve
  142  sudo mkdir -p /run/systemd/resolve
  143  sudo cp /etc/resolv.conf /run/systemd/resolve/resolv.conf
  144  networkctl
  145  vim /etc/systemd/resolved.conf
  146  ls
  147  networkctl status eth0
  148  networkctl status eth1
  149  networkctl status eth2
  150  networkctl status eth3

#!! don’t disable NetworkManager

just provided /run/systemd/resole/resolv.con (might copied from /etc/resolv.conf

when reboot machine beware of system swap to be off!!

#12-dns-addon
seem like node incorrect advertise their ip 10.0.2.15?
but pod seem like correctly assigned ip
container from different nodes should not be reachable
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")

Name:               coredns-699f8ddd77-xv74f
Namespace:          kube-system
Priority:           0
PriorityClassName:  <none>
Node:               tuf4/10.0.2.15
Start Time:         Tue, 16 Apr 2019 01:49:55 +0700
Labels:             k8s-app=kube-dns
                    pod-template-hash=699f8ddd77
Annotations:        <none>
Status:             Running
IP:                 10.200.4.2

Error from server: error dialing backend: dial tcp: lookup tuf4 on 10.0.2.3:53: no such host
Warning  Unhealthy  2m14s (x14 over 7m4s)  kubelet, tuf4      Liveness probe failed: HTTP probe failed with statuscode: 503

#13-smoke-test

