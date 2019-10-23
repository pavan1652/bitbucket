#!/bin/bash
​
# This schipt will check if the bitbucket NFS servers IP has changed, and if changed 
# stop Bitbucket, wait for NFS servers to be available on the new IP before bringing up Bitbucket
​
grep 10.17.224.2 /etc/resolv.conf > /dev/null
if [ $? -ne 0 ]; then
sed -i '/^search/a\'$'\n''nameserver 10.17.224.2' /etc/resolv.conf
fi
​
NFS_SERVER=`cat /etc/fstab |grep /var/atlassian/application-data/bitbucket/shared |awk -F: '{print $1}'`
IP=`host $NFS_SERVER| awk '{print $4}'`
​
if [ ! -z IP ]; then
​
echo "NFS_SERVER($NFS_SERVER) resolves to ($IP)"
​
echo "Checking if /var/atlassian/application-data/bitbucket/shared is mounted from $IP"
​
mount |grep bbnfs|grep $IP > /dev/null
​
if [ $? -eq 0 ]; then  
​
  echo "/var/atlassian/application-data/bitbucket/shared is mounted from $IP, NFS_SERVER IP hasn't changed" 
​
else 
​
  echo "NFS_SERVER IP has changed, stopping Bitbucket.."
​
  systemctl stop atlbitbucket
  
  sleep 10
​
  echo "Force unmounting /var/atlassian/application-data/bitbucket/shared"
​
  umount -lf /var/atlassian/application-data/bitbucket/shared
​
  echo "Waiting got $IP to be available on port 2049"
​
  NFS_PORT_ACCESS=0
​
  until [ $NFS_PORT_ACCESS -eq 1 ]; do
​
     nc -zv $IP 2049 > /dev/null
     
     if [ $? -eq 0 ]; then
      
       echo "Access to $IP on NFS port 2049 is open, mounting NFS share and starting Bitbucket"
       mount /var/atlassian/application-data/bitbucket/shared
       systemctl start atlbitbucket
       NFS_PORT_ACCESS=1
 
     else
​
       echo "Can't access $IP:2049.. sleeping 60s"
       sleep 10
​
     fi
​
  done
​
fi
    
fi