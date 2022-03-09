#!/bin/bash

#
# Builds a public and private subnet, inside a VPC, with a jump box to access the private subnet
# NOTE: this requires aws cli to be configured with admin access in the region selected 
#

# set config variables
. ./configuration/configuration.sh

# Create VPC and store ID to variable
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text)

# Create two subnets (private and public)
SN_PUBLIC=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --query Subnet.SubnetId --output text)
SN_PRIVATE=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.0.0/24 --query Subnet.SubnetId --output text)

# Create Internet gateway and attach to VPC
IG=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IG

# Create route table and routes
ROUTE_TABLE=$(aws ec2 create-route-table --vpc-id ${VPC_ID} --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id $ROUTE_TABLE --destination-cidr-block 0.0.0.0/0 --gateway-id $IG

# Associate route table with public subnet 
aws ec2 associate-route-table --subnet-id $SN_PUBLIC --route-table-id $ROUTE_TABLE

# Apply public ip for instances in public subnet 
aws ec2 modify-subnet-attribute --subnet-id $SN_PUBLIC --map-public-ip-on-launch

# Create security group for ssh access and open port 22
SG_SSH=$(aws ec2 create-security-group \
 --group-name SSHAccess \
 --description "Security group for SSH access" \
 --vpc-id ${VPC_ID} \
 --query GroupId \
 --output text)

# open port 22 in security group
aws ec2 authorize-security-group-ingress --group-id $SG_SSH --protocol tcp --port 22 --cidr 0.0.0.0/0

# Create IAM role for bastion instance to ssh into private subnet
aws iam create-role --path / \
--role-name EC2Admin \
--assume-role-policy-document file://admin.json

aws iam create-instance-profile --instance-profile-name ec2-bastion

aws iam add-role-to-instance-profile \
    --instance-profile-name ec2-bastion \
    --role-name EC2Admin

# Create key pair with chosen Key name
aws ec2 create-key-pair --key-name $KEY_NAME --query "KeyMaterial" --output text > configuration/${KEY_NAME}.pem

# assign correct permissions
chmod 400 configuration/${KEY_NAME}.pem

# Create instance in public subnet 
JUMP_BOX_ID=$(aws ec2 run-instances \
 --image-id ami-0892d3c7ee96c0bf7 \
 --iam-instance-profile Name="ec2-jump-box" \
 --count 1 \
 --instance-type t2.micro \
 --key-name $KEY_NAME \
 --security-group-ids $SG_SSH \
 --subnet-id $SN_PUBLIC | jq -r .Instances[0].InstanceId)

## Add nat gateway to public subnet
# Create elastic IP
E_IP=$(aws ec2 allocate-address | jq -r .AllocationId)

echo "VPC, private and public subnet created"
 
echo "VPC id is ${VPC_ID}"
echo "export VPC_ID=${VPC_ID}" > configuration/vpc_configs.sh

echo "Public subnet id is ${SN_PUBLIC}"
echo "export SN_PUBLIC=${SN_PUBLIC}" >> configuration/vpc_configs.sh

echo "Private subnet id is ${SN_PRIVATE}"
echo "export SN_PRIVATE=${SN_PRIVATE}" >> configuration/vpc_configs.sh

echo "Jump box instance id is ${JUMP_BOX_ID}"
echo "export JUMP_BOX_ID=${JUMP_BOX_ID}" >> configuration/vpc_configs.sh

echo "export KEY_LOCATION=configuration/${KEY_NAME}.pem" >> configuration/vpc_configs.sh

echo "export SG_SSH=${SG_SSH}" >> configuration/vpc_configs.sh