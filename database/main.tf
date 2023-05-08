resource "aws_security_group" "tp_rds_sg" {
  name = "tp-rds-sg"

  ingress {
    from_port = 0
    to_port = 0
    protocol = "all"
    cidr_blocks = ["109.155.19.77/32"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "all"
    self = true
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "tp_rds_pg" {
  name = "tp-rds-pg"
  family = "postgres13"
  parameter {
    name = "rds.logical_replication" 
    value = 1 
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "tp_rds" {
  identifier = "tp-rds"
  allocated_storage = 10
  storage_type = "gp2"
  engine = "postgres"
  engine_version = "13.7"
  instance_class = "db.t3.micro"
  db_name = "tplake"
  username = "postgres"
  password = "postgres"
  vpc_security_group_ids = [aws_security_group.tp_rds_sg.id]
  publicly_accessible = true
  parameter_group_name = aws_db_parameter_group.tp_rds_pg.name
  skip_final_snapshot = true
}

