#!/bin/bash

#
# Builds infrastructure for kafka brokers
# Usage: <Required number of brokers>
#

COUNTER=1
BROKER_IPS=()

# set config variables
. ./configuration/vpc_configs.sh
. ./configuration/configuration.sh

# Create NAT gateway 
NAT_ID=$(aws ec2 create-nat-gateway \
 --subnet-id $SN_PUBLIC \
 --allocation-id $E_IP | jq -r .NatGateway.NatGatewayId)

echo "export NAT_ID=${NAT_ID}" >> configuration/vpc_configs.sh

# Get default route table id
ROUTE_TABLE_DEFAULT=$(aws ec2 describe-route-tables \
 --filters "Name=association.main,Values=true" "Name=vpc-id,Values=${VPC_ID}" \
 --query=RouteTables[*].RouteTableId \
 --output=text )

# Get Bastion instance Public IP
JUMP_BOX_IP=$(aws ec2 describe-instances\
 --filters "Name=instance-state-name,Values=running" "Name=instance-id,Values=${JUMP_BOX_ID}"\
 --query 'Reservations[*].Instances[*].[PublicIpAddress]'\
 --output text)

echo "export NAT_ID=${JUMP_BOX_IP}" >> configuration/vpc_configs.sh

# Associate NAT gateway with default route table
aws ec2 create-route \
 --route-table-id  $ROUTE_TABLE_DEFAULT \
 --destination-cidr-block 0.0.0.0/0 \
 --nat-gateway-id $NAT_ID
 
cp ./configuration/hostsSample configuration/hosts
cp ./configuration/zookeeperSample.properties configuration/zookeeper.properties

# Create security group for kafka broker
SG_KAFKA=$(aws ec2 create-security-group \
 --group-name KafkaBroker \
 --description "Security group for KafkaBroker" \
 --vpc-id ${VPC_ID} \
 --query GroupId \
 --output text)

# open port 22 in security group
aws ec2 authorize-security-group-ingress --group-id $SG_KAFKA --protocol tcp --port 22 --cidr 10.0.0.0/16

# open port 2181 in security group for zookeeper
aws ec2 authorize-security-group-ingress --group-id $SG_KAFKA --protocol tcp --port 2181 --cidr 10.0.0.0/24

# open port 9092 in security group for kafka
aws ec2 authorize-security-group-ingress --group-id $SG_KAFKA --protocol tcp --port 9092 --cidr 10.0.0.0/16

# open port	2888 - 3888 in security group 
aws ec2 authorize-security-group-ingress --group-id $SG_KAFKA --protocol tcp --port 2888-3888 --cidr 10.0.0.0/24

# Create EC2 instances in the private subnet
while [  $COUNTER -lt $(($1+1)) ];
do

   aws ec2 run-instances \
 --image-id ${AMI} \
 --count 1 \
 --instance-type "t2.large" \
 --key-name ${KEY_NAME} \
 --subnet-id ${SN_PRIVATE} \
 --block-device-mappings "[{\"DeviceName\":\"/dev/sdf\",\"Ebs\":{\"VolumeSize\":${VOLUME_SIZE},\"DeleteOnTermination\":false}}]" \
 --private-ip-address "10.0.2.1${COUNTER}" \
 --security-group-ids ${SG_KAFKA}  
     
   BROKER_IPS+=("10.0.2.1${COUNTER}")
   echo "10.0.2.1${COUNTER} zoo${COUNTER}" >> configuration/hosts
   echo "server.${COUNTER}=zoo${COUNTER}:2888:3888" >> configuration/zookeeper.properties
   let COUNTER=COUNTER+1 
done

# Instance for ksql in public subnet
KSQL_ID=$(aws ec2 run-instances \
 --image-id ${AMI} \
 --count 1 \
 --instance-type "t2.large" \
 --key-name ${KEY_NAME} \
 --subnet-id ${SN_PUBLIC} \
 --block-device-mappings "[{\"DeviceName\":\"/dev/sdf\",\"Ebs\":{\"VolumeSize\":${VOLUME_SIZE},\"DeleteOnTermination\":false}}]" \
 --security-group-ids ${SG_SSH} | jq -r .Instances[0].InstanceId) 

# Instance for REST proxyaws ec2 run-instances \
K_REST_ID=$(aws ec2 run-instances \
 --image-id ${AMI} \
 --count 1 \
 --instance-type "t2.micro" \
 --key-name ${KEY_NAME} \
 --subnet-id ${SN_PUBLIC} \
 --block-device-mappings "[{\"DeviceName\":\"/dev/sdf\",\"Ebs\":{\"VolumeSize\":${VOLUME_SIZE},\"DeleteOnTermination\":false}}]" \
 --security-group-ids ${SG} | jq -r .Instances[0].InstanceId)

echo "Broker IPs are ${BROKER_IPS[*]}"
echo "export BROKER_IPS=${BROKER_IPS[*]}" > configuration/broker_ips.sh

echo "export KSQL_ID=${KSQL_ID}" >> configuration/vpc_configs.sh
echo "export K_REST_ID=${K_REST_ID}" >> configuration/vpc_configs.sh
