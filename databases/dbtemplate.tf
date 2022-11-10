# Check Postgres: cd to root folder and execute:
# export PGPASSWORD=12345678&& psql -U postgresuser -d postgresdb -h HOST FROM OUTPUT WITHOUT PORT -f ./rds-script.sql
# Check dynnamo: cd to root folder and execute:
# sh dynamodb-script.sh

provider "aws" {
  region = "us-east-1"
}

variable "ami" {
  description = "Ami for ec2"
  type        = string
  default     = "ami-026b57f3c383c2eec"
}

variable "type" {
  description = "Type for ec2"
  type        = string
  default     = "t2.micro"
}

variable "rds_type" {
  description = "Type for RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "vpc_id" {
  description = "Default VPC ID"
  type        = string
  default     = "vpc-0e13871ed8ba86f71"
}

variable "default_subnet" {
  description = "Defaukt subnet for RDS"
  type        = string
  default     = "default-vpc-0e13871ed8ba86f71"
}

resource "aws_db_instance" "mypostgresdb" {
  allocated_storage       = 200
  backup_retention_period = 0
  skip_final_snapshot     = true
  db_subnet_group_name    = var.default_subnet
  engine                  = "postgres"
  engine_version          = "13.7"
  identifier              = "postgresdb"
  instance_class          = var.rds_type
  multi_az                = false
  db_name                 = "postgresdb"
  password                = "12345678"
  port                    = 5432
  publicly_accessible     = true
  storage_encrypted       = true
  storage_type            = "gp2"
  username                = "postgresuser"
  vpc_security_group_ids  = ["${aws_security_group.postgresgroup.id}"]
}

resource "aws_security_group" "postgresgroup" {
  name = "postgresgroup"

  description = "RDS test"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2_example" {

  ami                    = var.ami
  instance_type          = var.type
  key_name               = "default-ssh-key"
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.http.id, aws_security_group.postgresgroup.id]
  iam_instance_profile   = aws_iam_instance_profile.my_profile.name
  user_data              = <<EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install postgresql -y
  aws s3 cp s3://may-test-2022-1/rds-script.sql rds-script.sql
  aws s3 cp s3://may-test-2022-1/dynamodb-script.sh dynamodb-script.sh
EOF
}

resource "aws_security_group" "ssh" {
  name = "ssh-group"
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    }
  ]
}

resource "aws_security_group" "http" {
  name = "http-group"
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
    }
  ]
}

resource "aws_iam_role" "my_role" {
  name = "MyRole"
  assume_role_policy = jsonencode({
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      },
      {
        "Effect" : "Allow",
        "Sid" : "",
        "Principal" : {
          "Service" : "dynamodb.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "my_profile" {
  name = "MyProfile"
  role = aws_iam_role.my_role.name
}

resource "aws_iam_role_policy" "my_role_policy" {
  name = "MyRolePolicy"
  role = aws_iam_role.my_role.id
  policy = jsonencode({
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*"
        ],
        "Resource" : [
          "arn:aws:s3:::may-test-2022-1",
          "arn:aws:s3:::may-test-2022-1/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : ["dynamodb:*"],
        "Resource" : "${aws_dynamodb_table.dynamo-test.arn}"
      }
    ]
  })
}

resource "aws_dynamodb_table" "dynamo-test" {
  name           = "dynamo-test"
  billing_mode   = "PROVISIONED"
  read_capacity  = "10"
  write_capacity = "10"

  attribute {
    name = "id"
    type = "S"
  }

  hash_key = "id"

  ttl {
    enabled        = true
    attribute_name = "expiryPeriod"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

output "postgres_endpoint" {
  description = "Postgres endpoint with port"
  value       = aws_db_instance.mypostgresdb.endpoint
}

output "instance_public_ip" {
  description = "Public ip of EC2"
  value       = aws_instance.ec2_example.public_ip
}
