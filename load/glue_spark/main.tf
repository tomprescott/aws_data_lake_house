resource "aws_glue_job" "spark_upsert" {
  name         = "spark-upsert-${var.table_name}"
  role_arn     = var.glue_role
  command {
    name        = "glueetl"
    script_location = "s3://tp-lake-dev/scripts/spark_upsert.py"
    python_version = "3"
  }

  glue_version = "3.0"
  worker_type = "G.1X"
  number_of_workers = 2

  default_arguments = {
    "--bucket" = var.bucket
    "--out_bucket" = var.out_bucket
    "--prefix" = var.prefix
    "--out_prefix" = var.out_prefix
  }
}

resource "aws_glue_crawler" "glue_crawler" {
  name = "pg_${var.table_name}"

  role = var.glue_role
  database_name = "silver"

  s3_target {
    path = "s3://${var.out_bucket}/${var.out_prefix}"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }
}

resource "aws_s3_bucket_object" "spark_upsert" {
  bucket = "tp-lake-dev"
  key    = "scripts/spark_upsert.py"
  source = "${path.module}/spark_upsert.py"
}

