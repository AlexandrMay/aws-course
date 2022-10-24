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

resource "aws_instance" "ec2_example" {

  ami                    = var.ami
  instance_type          = var.type
  key_name               = "default-ssh-key"
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.http.id]
  iam_instance_profile   = aws_iam_instance_profile.my_profile.name
  user_data              = <<EOF
  #!/bin/bash
  sudo yum install awscli -y
  aws s3 cp s3://may-test-2022/test.txt test.txt
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
          "arn:aws:s3:::may-test-2022",
          "arn:aws:s3:::may-test-2022/*"
        ]
      }
    ]
  })
}

output "instance_public_ip" {
  description = "Public ip of EC2"
  value       = aws_instance.ec2_example.public_ip
}
