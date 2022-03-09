# KafkaAWS

Infrastructure code to set up a kafka cluster in a private VPC on AWS. It can be adapted to set 
up other database clusters that require to be inside private subnets.

## Requirements

- jq 1.6.x
- aws cli 1.18.x

## Set up VPC 

The AWS cli needs to configured to be in the region for the target VPC, this can be done by 

```sh
$ aws configure
```

Declare the name of the ssh key for the cluster instances in the shell e.g.

```sh
export KEY_NAME=<name of key>
```

Build the VPC, private and public subnets

```sh
./buildVPC.sh
```

On completion, the script should create a config file at `./configuration/vpc_configs.sh`, like
the example below

```
export VPC_ID=vpc-0184133377f1da725
export SN_PUBLIC=subnet-02ffc33598a94ec4f
export SN_PRIVATE=subnet-06e3e16ce5ccda2f3
export JUMP_BOX_ID=i-0e52487e72d78a143
export KEY_LOCATION=configuration/kafka-cluster.pem
export SG_SSH=sg-05fa9da133106d93c
```

## Set up infrastructure (instances) in private subnet

Build the infrastructure with the following command, specifiying the number
of instances/brokers required in the kafka cluster as the first argument,

```sh
./buildInfra.sh 3
```

## Install Kafka

Install Kafka and zookeeper across all instances,

```sh
./installKafka.sh
```