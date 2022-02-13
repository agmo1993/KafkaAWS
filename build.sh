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
   echo "zoo${COUNTER} 10.0.2.1${COUNTER}" >> configuration/hosts
   echo "server.${COUNTER}=zoo${COUNTER}:2888:3888" >> configuration/zookeeper.properties
   let COUNTER=COUNTER+1 
done

# Configure the Kafka brokers, install openjdk and confluence community

INDEX=1
for IP in "${BROKER_IPS[@]}"
do
    # Install openjdk and confluent-community
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "wget -qO - https://packages.confluent.io/deb/5.2/archive.key | sudo apt-key add -"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo add-apt-repository 'deb [arch=amd64] https://packages.confluent.io/deb/5.2 stable main'"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo apt-get update && sudo apt-get install -y openjdk-8-jdk confluent-community-${C_VERSION}"

    # Configure Zookeeper and Kafka
    scp -i ${KEY_LOCATION} ./configuration/hosts ubuntu@${IP}:/home/ubuntu
    scp -i ${KEY_LOCATION} ./configuration/zookeeper.properties ubuntu@${IP}:/home/ubuntu
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo mv ./hosts /etc" 
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo mv ./zookeeper.properties /etc/kafka"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "echo "${INDEX}" | sudo tee -a /var/lib/zookeeper/myid"
    sed "s/BrokerID/${INDEX}/g" ./configuration/serverSample.properties > ./configuration/server.properties
    scp -i ${KEY_LOCATION} ./configuration/server.properties ubuntu@${IP}:/home/ubuntu
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo mv ./hosts /etc/kafka" 
    let INDEX=INDEX+1 
done

# Start the zookeeper instances, once the configurations have been set
for IP in "${BROKER_IPS[@]}"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo systemctl start confluent-zookeeper; sudo systemctl enable confluent-zookeeper"
do

# Start Kafka instances on each broker, after providing some time for zookeeper to start
sleep 10

# Start the zookeeper instances, once the configurations have been set
for IP in "${BROKER_IPS[@]}"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo systemctl start confluent-kafka; sudo systemctl enable confluent-kafka"
do