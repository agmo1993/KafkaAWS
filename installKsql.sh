#!/bin/bash

# Install ksql in public subnet
. ./configuration/vpc_configs.sh
. ./configuration/configuration.sh

# Get instance IP address
I_IP=$(aws ec2 describe-instances \
 --instance-ids ${KSQL_ID} | jq -r .Reservations[0].Instances[0].PublicIpAddress)

ssh ubuntu@${I_IP} -i ${KEY_LOCATION} -o "StrictHostKeyChecking=no" "wget -qO - https://packages.confluent.io/deb/5.2/archive.key | sudo apt-key add -"
ssh ubuntu@${I_IP} -i ${KEY_LOCATION} -o "StrictHostKeyChecking=no" "sudo add-apt-repository 'deb [arch=amd64] https://packages.confluent.io/deb/5.2 stable main'"
ssh ubuntu@${I_IP} -i ${KEY_LOCATION} -o "StrictHostKeyChecking=no" "sudo apt-get update && sudo apt-get install -y openjdk-8-jdk confluent-community-${C_VERSION}"
scp -i ${KEY_LOCATION} ./configuration/ksql-server.properties ubuntu@${I_IP}:/home/ubuntu
scp -i ${KEY_LOCATION} ./configuration/hosts ubuntu@${I_IP}:/home/ubuntu
ssh ubuntu@${I_IP} -i ${KEY_LOCATION} "sudo mv ./ksql-server.properties /etc/ksql"
ssh ubuntu@${I_IP} -i ${KEY_LOCATION} "sudo mv ./hosts /etc" 
ssh ubuntu@${I_IP} -i ${KEY_LOCATION} "sudo systemctl start confluent-ksql; sudo systemctl enable confluent-ksql"