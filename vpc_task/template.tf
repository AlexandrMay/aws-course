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

variable "public_avaliability_zone" {
  description = "Avaliability zone for public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "private_avaliability_zone" {
  description = "Avaliability zone for private subnet"
  type        = string
  default     = "us-east-1b"
}

variable "ec2_nat_ami" {
  description = "AMI for ec2 nat instance from Community AMIs"
  type        = string
  default     = "ami-08f495eb9d4054bd3"
}

variable "ssh_key" {
  description = "Default SSH key name"
  type        = string
  default     = "default-ssh-key"
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "My Test VPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.public_avaliability_zone
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.private_avaliability_zone
  map_public_ip_on_launch = false
  tags = {
    Name = "Private Subnet"
  }
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

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
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
  instance_id   = aws_instance.ec2_nat.id
}

resource "aws_instance" "ec2_nat" {
  ami                    = var.ec2_nat_ami
  instance_type          = var.type
  key_name               = var.ssh_key
  subnet_id              = aws_subnet.public_subnet.id
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  tags = {
    Name = "EC2 NAT"
  }
}

resource "aws_instance" "ec2_public" {
  ami                    = var.ami
  instance_type          = var.type
  key_name               = var.ssh_key
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.my_profile.name
  tags = {
    Name = "EC2 with public access"
  }
  user_data = <<EOF
  #!/bin/bash
  sudo yum update -y
  aws s3 cp s3://may-test-2022/default-ssh-key.pem default-ssh-key.pem
  sudo chmod 400 default-ssh-key.pem
  sudo yum install httpd -y
  service httpd start
  chkconfig httpd on
  cd /var/www/html
  echo "<html><h1>This is Web Server from my PUBLIC subnet!</h1></html>" > index.html
EOF
}

resource "aws_instance" "ec2_private" {
  ami                    = var.ami
  instance_type          = var.type
  key_name               = var.ssh_key
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  tags = {
    Name = "EC2 with private access"
  }
  user_data = <<EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install httpd -y
  service httpd start
  chkconfig httpd on
  cd /var/www/html
  echo "<html><h1>This is Web Server from my PRIVATE subnet!</h1></html>" > index.html
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
      cidr_blocks      = ["10.0.1.0/24"]
      description      = ""
      from_port        = -1
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "icmp"
      security_groups  = []
      self             = false
      to_port          = -1
    },
    {
      cidr_blocks      = ["10.0.1.0/24"]
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
      cidr_blocks      = ["10.0.1.0/24"]
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

resource "aws_lb_target_group" "lb_target_group" {
  name     = "TargetGroupForLoadBalancing"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path = "/index.html"
  }
}

resource "aws_lb_target_group_attachment" "public_ec2_target" {
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id        = aws_instance.ec2_public.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "private_ec2_target" {
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id        = aws_instance.ec2_private.id
  port             = 80
}

resource "aws_lb" "lb" {
  name                       = "LoadBalancer"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.public_sg.id]
  subnets                    = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]
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

output "dns_name" {
  description = "Public ip of EC2"
  value       = aws_lb.lb.dns_name
}
