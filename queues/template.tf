# SNS command to send the notification:
# aws sns publish --topic-arn topic_arn_from_output --message “test” --region us-east-1
# SQS commands to send and receive message:
# aws sqs send-message --queue-url queue_url_from_output --message-body “test” --region us-east-1
# aws sqs receive-message --queue-url queue_url_from_output --attribute-names All --message-attribute-names All --max-number-of-messages 10 --region us-east-1

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
  vpc_security_group_ids = [aws_security_group.myssh.id, aws_security_group.myhttp.id]
  iam_instance_profile   = aws_iam_instance_profile.my_profile.name
  user_data              = <<EOF
  #!/bin/bash
  sudo yum update -y
EOF
}

resource "aws_security_group" "myssh" {
  name = "my-ssh-group"
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

resource "aws_security_group" "myhttp" {
  name = "my-http-group"
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

resource "aws_sns_topic" "my_sns" {
  name = "my_sns"
}

resource "aws_sqs_queue" "my_sqs" {
  name                      = "my_sqs"
  visibility_timeout_seconds = 30
  delay_seconds             = 0
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 0
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
          "SNS:Publish"
        ],
        "Resource" : [
          "${aws_sns_topic.my_sns.arn}"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "sqs:*"
        ],
        "Resource" : [
          "${aws_sqs_queue.my_sqs.arn}"
        ]
      }
    ]
  })
}

output "instance_public_ip" {
  description = "Public ip of EC2"
  value       = aws_instance.ec2_example.public_ip
}

output "sns_arn" {
  description = "Arn of SNS"
  value       = aws_sns_topic.my_sns.arn
}

output "sqs_url" {
  description = "Url of SQS"
  value       = aws_sqs_queue.my_sqs.url
}