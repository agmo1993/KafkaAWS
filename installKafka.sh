#!/bin/bash

# Configure the Kafka brokers, install openjdk and confluence community
. ./configuration/broker_ips.sh
echo "${BROKER_IPS[*]}"

INDEX=1
for IP in "${BROKER_IPS[@]}"
do
    # Install openjdk and confluent-community
    echo "Configure broker at ${IP}"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} -o "StrictHostKeyChecking=no" "wget -qO - https://packages.confluent.io/deb/5.2/archive.key | sudo apt-key add -"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} -o "StrictHostKeyChecking=no" "sudo add-apt-repository 'deb [arch=amd64] https://packages.confluent.io/deb/5.2 stable main'"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} -o "StrictHostKeyChecking=no" "sudo apt-get update && sudo apt-get install -y openjdk-8-jdk confluent-community-${C_VERSION}"

    # Configure Zookeeper and Kafka
    scp -i ${KEY_LOCATION} ./configuration/hosts ubuntu@${IP}:/home/ubuntu
    scp -i ${KEY_LOCATION} ./configuration/zookeeper.properties ubuntu@${IP}:/home/ubuntu
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo mv ./hosts /etc" 
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo mv ./zookeeper.properties /etc/kafka"
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "echo "${INDEX}" | sudo tee -a /var/lib/zookeeper/myid"
    sed "s/BrokerID/${INDEX}/g" ./configuration/serverSample.properties > ./configuration/server.properties
    scp -i ${KEY_LOCATION} ./configuration/server.properties ubuntu@${IP}:/home/ubuntu
    ssh ubuntu@${IP} -i ${KEY_LOCATION} "sudo mv ./server.properties /etc/kafka" 
    let INDEX=INDEX+1 
done

# Start the zookeeper instances, once the configurations have been set
for IP_ADD in "${BROKER_IPS[@]}"
do
    ssh ubuntu@${IP_ADD} -i ${KEY_LOCATION} "sudo systemctl start confluent-zookeeper; sudo systemctl enable confluent-zookeeper"
    sleep 5
done

# Start Kafka instances on each broker, after providing some time for zookeeper to start
sleep 15

# Start the zookeeper instances, once the configurations have been set
for IP_ADD in "${BROKER_IPS[@]}"
do
    ssh ubuntu@${IP_ADD} -i ${KEY_LOCATION} "sudo systemctl start confluent-kafka; sudo systemctl enable confluent-kafka"
    sleep 5
done
