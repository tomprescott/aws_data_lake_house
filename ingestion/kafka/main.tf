provider "aws" {
  region = "eu-west-2"
}

locals {
  vpc_id = "vpc-25b2d44d"
}

resource "aws_security_group" "lake_msk_client_sg" {
  name        = "lake-msk-client-sg"
  description = "Security group for Kafka"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tp-lake"
  }
}

resource "aws_security_group" "lake_msk_cluster_sg" {
  name        = "lake-msk-cluster-sg"
  description = "Security group for Kafka"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 0 
    to_port     = 0
    protocol    = -1
    security_groups = [aws_security_group.lake_msk_client_sg.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tp-lake"
  }
}

resource "aws_iam_role" "lake_msk_client_role" {
  name = "lake-msk-client-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Name = "tp-lake"
  }
}

resource "aws_iam_role_policy_attachment" "lake_msk_policy_attachment" {
  role = aws_iam_role.lake_msk_client_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonMSKFullAccess"
}

resource "aws_iam_instance_profile" "lake_client_instance_profile" {
  name  = "lake-client-instance-profile"
  role = aws_iam_role.lake_msk_client_role.name
}

resource "aws_msk_cluster" "lake_msk_cluster" {
  cluster_name     = "tp-kafka-cluster"
  kafka_version    = "2.8.1"
  number_of_broker_nodes = 3

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster = true
    }
  }

  broker_node_group_info {
    client_subnets = ["subnet-20a3175a", "subnet-eabdd583", "subnet-1152a95d"]
    security_groups = [aws_security_group.lake_msk_cluster_sg.id]
    instance_type = "kafka.t3.small"
  }

  tags = {
    Name = "tp-lake"
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user_data.tpl")
}

resource "aws_instance" "lake_msk_client" {
  ami           = "ami-08cd358d745620807"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.lake_msk_client_sg.id]
  subnet_id = "subnet-20a3175a"
  iam_instance_profile = aws_iam_instance_profile.lake_client_instance_profile.name
  user_data = data.template_file.user_data.rendered
  key_name = "tp-ssh"

  tags = {
    Name = "tp-lake"
  }
}

