provider "aws" {
  region = "us-west-2"
}

variable "ami" {
  description = "Ami for ec2"
  type        = string
  default     = "ami-094125af156557ca2"
}

variable "private_ami" {
  description = "Ami for private ec2"
  type        = string
  default     = "ami-08e4eaf54ff5ee95e"
}

variable "type" {
  description = "Type for ec2"
  type        = string
  default     = "t2.micro"
}

variable "public_avaliability_zone_1" {
  description = "Avaliability zone for public subnet"
  type        = string
  default     = "us-west-2a"
}

variable "public_avaliability_zone_2" {
  description = "Avaliability zone for public subnet"
  type        = string
  default     = "us-west-2b"
}

variable "private_avaliability_zone_1" {
  description = "Avaliability zone for private subnet"
  type        = string
  default     = "us-west-2c"
}

variable "private_avaliability_zone_2" {
  description = "Avaliability zone for private subnet"
  type        = string
  default     = "us-west-2d"
}

variable "ec2_nat_ami" {
  description = "AMI for ec2 nat instance from Community AMIs"
  type        = string
  default     = "ami-0f95da1ca59f7dea0"
}

variable "ssh_key" {
  description = "Default SSH key name"
  type        = string
  default     = "my_key"
}

variable "rds_type" {
  description = "Type for RDS"
  type        = string
  default     = "db.t3.micro"
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "My Test VPC"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.public_avaliability_zone_1
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.public_avaliability_zone_2
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = var.private_avaliability_zone_1
  map_public_ip_on_launch = false
  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = var.private_avaliability_zone_2
  map_public_ip_on_launch = false
  tags = {
    Name = "Private Subnet 2"
  }
}

resource "aws_db_subnet_group" "private_subnet_group" {
  name       = "private_subnet_group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

resource "aws_internet_gateway" "inet_gw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "My Inet Gateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Public route table"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Private route table"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.inet_gw.id
}

resource "aws_route" "private_internet_gateway" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.ec2_nat.id
}

resource "aws_instance" "ec2_nat" {
  ami                    = var.ec2_nat_ami
  instance_type          = var.type
  key_name               = var.ssh_key
  subnet_id              = aws_subnet.public_subnet_1.id
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  tags = {
    Name = "EC2 NAT"
  }
}

resource "aws_launch_template" "my_launch_template" {
  image_id               = var.ami
  instance_type          = var.type
  key_name               = var.ssh_key
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.my_profile.name
  }
  user_data = filebase64("user_data.sh")
}

resource "aws_autoscaling_group" "my_asg" {
  desired_capacity    = 2
  max_size            = 2
  min_size            = 2
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  launch_template {
    id = aws_launch_template.my_launch_template.id
  }
  target_group_arns = [ "${aws_lb_target_group.lb_target_group.arn}" ]
}

resource "aws_instance" "ec2_private" {
  ami                    = var.private_ami
  instance_type          = var.type
  key_name               = var.ssh_key
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.private_sg.id, aws_security_group.postgresgroup.id]
  iam_instance_profile   = aws_iam_instance_profile.my_profile.name
  tags = {
    Name = "EC2 with private access"
  }
  user_data = <<EOF
  #!/bin/bash
  sudo su
  yum update -y
  yum install -y java-1.8.0
  yum install postgresql -y
  echo 'export PGPASSWORD="rootuser"' >> /etc/profile
  echo 'export RDS_HOST="${aws_db_instance.mypostgresdb.endpoint}"' >> /etc/profile
  aws s3 cp s3://may-test-2022/persist3-2021-0.0.1-SNAPSHOT.jar persist3-2021-0.0.1-SNAPSHOT.jar
EOF
}

resource "aws_security_group" "public_sg" {
  name   = "Public group"
  vpc_id = aws_vpc.my_vpc.id
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
    },
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 443
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 443
    },
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

resource "aws_security_group" "private_sg" {
  name   = "Private group"
  vpc_id = aws_vpc.my_vpc.id
  ingress = [
    {
      cidr_blocks      = ["10.0.1.0/24", "10.0.2.0/24"]
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
          "arn:aws:s3:::may-test-2022",
          "arn:aws:s3:::may-test-2022/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : ["dynamodb:*"],
        "Resource" : "${aws_dynamodb_table.dynamo-test.arn}"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "SNS:*"
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

resource "aws_dynamodb_table" "dynamo-test" {
  name           = "edu-lohika-training-aws-dynamodb"
  billing_mode   = "PROVISIONED"
  read_capacity  = "10"
  write_capacity = "10"

  attribute {
    name = "UserName"
    type = "S"
  }

  hash_key = "UserName"

  ttl {
    enabled        = true
    attribute_name = "expiryPeriod"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_db_instance" "mypostgresdb" {
  allocated_storage       = 200
  backup_retention_period = 0
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.private_subnet_group.name
  engine                  = "postgres"
  engine_version          = "13.7"
  instance_class          = var.rds_type
  multi_az                = false
  db_name                 = "EduLohikaTrainingAwsRds"
  password                = "rootuser"
  port                    = 5432
  publicly_accessible     = true
  storage_encrypted       = true
  storage_type            = "gp2"
  username                = "rootuser"
  vpc_security_group_ids  = ["${aws_security_group.postgresgroup.id}"]
}

resource "aws_security_group" "postgresgroup" {
  name = "postgresgroup"

  description = "RDS test"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_sns_topic" "my_sns" {
  name = "edu-lohika-training-aws-sns-topic"
}

resource "aws_sqs_queue" "my_sqs" {
  name                       = "edu-lohika-training-aws-sqs-queue"
  visibility_timeout_seconds = 30
  delay_seconds              = 0
  max_message_size           = 2048
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 0
}

resource "aws_lb_target_group" "lb_target_group" {
  name     = "TargetGroupForLoadBalancing"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path = "/health"
  }
}

resource "aws_lb" "lb" {
  name               = "LoadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}
