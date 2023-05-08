#!/bin/sh
rm -f /var/run/yum.pid
yes | yum install java-1.8.0
cd /home/ec2-user/
wget https://archive.apache.org/dist/kafka/2.8.1/kafka_2.13-2.8.1.tgz
tar -xzf kafka_2.13-2.8.1.tgz
chown -R ec2-user:ec2-user /home/ec2-user/kafka_2.13-2.8.1

