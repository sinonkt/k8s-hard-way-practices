kubectl expose deployment nginx --port 80 --type NodePort
NODE_PORT=$(kubectl get svc nginx \
    --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
EXTERNAL_IP=172.17.8.101
curl -I http://${EXTERNAL_IP}:${NODE_PORT}
