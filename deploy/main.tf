locals {
  bucket = "tp-lake-dev"
}

terraform {
  backend "s3" {
    bucket = "tp-lake-dev"
    key    = "terraform/tp-lake-dev-ingestion.tfstate"
    region = "eu-west-2"
  }
}

#module "tp_lake_kafka" {
#  source = "../ingestion/kafka"
#}

module "tp_rds" {
 source = "../database"
}

module "tp_dms" {
  source = "../ingestion/dms"
  rds_username = module.tp_rds.rds_username
  rds_password = "postgres"
  server_name = module.tp_rds.rds_address
  db_name = "tplake"
  db_sg_id = module.tp_rds.rds_security_group_id
}

resource "aws_iam_role" "glue_admin_role" {
  name = "glue-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}

resource "aws_dynamodb_table" "dms_control_table" {
  name         = "DMSCDC_Controller"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "path"

  attribute {
    name = "path"
    type = "S"
  }
}

module "spark_upsert_customers" {
  source = "../load/glue_spark"
  bucket = local.bucket
  out_bucket = local.bucket
  prefix = "dms-data/public/customers"
  out_prefix = "silver/customers"
  glue_role = aws_iam_role.glue_admin_role.arn
  table_name = "customers"
}

module "spark_upsert_bank_accounts" {
  source = "../load/glue_spark"
  bucket = local.bucket
  out_bucket = local.bucket
  prefix = "dms-data/public/bank_accounts"
  out_prefix = "silver/bank_accounts"
  glue_role = aws_iam_role.glue_admin_role.arn
  table_name = "bank_accounts"
}

module "spark_upsert_transactions" {
  source = "../load/glue_spark"
  bucket = local.bucket
  out_bucket = local.bucket
  prefix = "dms-data/public/transactions"
  out_prefix = "silver/transactions"
  glue_role = aws_iam_role.glue_admin_role.arn
  table_name = "transactions"
}

module "glue_iceberg" {
  source = "../load/glue_iceberg"
}

module "airflow" {
  source = "../orchestration/airflow"
  vpc_id = "vpc-25b2d44d"
  subnet_ids = ["subnet-1152a95d", "subnet-eabdd583"]
}
