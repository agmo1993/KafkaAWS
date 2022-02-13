#!/bin/bash

COUNTER=1
BROKER_IPS=()

cp ./configuration/hostsSample configuration/hosts
cp ./configuration/zookeeperSample.properties configuration/zookeeper.properties

# Create EC2 instances in the private subnet

while [  $COUNTER -lt $(($1+1)) ];
do

   aws ec2 run-instances \
 --image-id ${AMI} \
 --count 1 \
 --instance-type ${INSTANCE_TYPE} \
 --key-name ${KEY_NAME} \
 --subnet-id ${SUBNET_ID} \
 --block-device-mappings "[{\"DeviceName\":\"/dev/sdf\",\"Ebs\":{\"VolumeSize\":${VOLUME_SIZE},\"DeleteOnTermination\":false}}]" \
 --private-ip-address "10.0.2.1${COUNTER}" \
 --security-group-ids ${SG}  
     
   BROKER_IPS+=("10.0.2.1${COUNTER}")
   echo "10.0.2.1${COUNTER} zoo${COUNTER}" >> configuration/hosts
   echo "server.${COUNTER}=zoo${COUNTER}:2888:3888" >> configuration/zookeeper.properties
   let COUNTER=COUNTER+1 
done

echo "Broker IPs are ${BROKER_IPS[*]}"
