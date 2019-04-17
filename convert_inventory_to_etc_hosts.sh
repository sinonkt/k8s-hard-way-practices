rm -f hosts
touch hosts
while IFS=, read -r Node InternalIP ExternalIP IsController IsWorker PodCIDR
do 
  echo "$InternalIP    $Node" >> hosts
  echo "$ExternalIP    $Node" >> hosts
done < inventory.csv
