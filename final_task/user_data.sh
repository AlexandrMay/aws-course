#!/bin/bash
sudo su
yum update -y
yum install -y java-1.8.0
aws s3 cp s3://may-test-2022/my_key.pem my_key.pem
chmod 400 my_key.pem
aws s3 cp s3://may-test-2022/calc-2021-0.0.1-SNAPSHOT.jar calc-2021-0.0.1-SNAPSHOT.jar