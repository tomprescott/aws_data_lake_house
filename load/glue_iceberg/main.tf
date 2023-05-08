resource "aws_iam_role" "glue_admin_role" {
  name = "GlueAdminRole"

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
}

resource "aws_iam_role_policy_attachment" "glue_admin_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.glue_admin_role.name
}

resource "aws_s3_bucket_object" "iceberg_customers_job" {
  bucket = "tp-lake-dev"
  key    = "scripts/iceberg_customers_job.py"
  etag   = filemd5("${path.module}/iceberg_customers_job.py")
  source = "${path.module}/iceberg_customers_job.py"
}

resource "aws_glue_job" "iceberg_customers_job" {
  name     = "iceberg_customers_job" 
  role_arn = aws_iam_role.glue_admin_role.arn
  glue_version = "4.0"
  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://tp-lake-dev/scripts/iceberg_customers_job.py"
  }

  default_arguments = {
    "--job-language"        = "python"
    "--datalake-formats"    = "iceberg"
    "--conf"                = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://tp-lake-dev/iceberg --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO"
    "--iceberg_job_catalog_warehouse" = "s3://tp-lake-dev-silver/iceberg"
    "--job-bookmark-option" = "job-bookmark-enable" 
  }
}

resource "aws_s3_bucket_object" "iceberg_transactions_job" {
  bucket = "tp-lake-dev"
  key    = "scripts/iceberg_transactions_job.py"
  etag   = filemd5("${path.module}/iceberg_transactions_job.py")
  source = "${path.module}/iceberg_transactions_job.py"
}

resource "aws_glue_job" "iceberg_transactions_job" {
  name     = "iceberg_transactions_job" 
  role_arn = aws_iam_role.glue_admin_role.arn
  glue_version = "4.0"
  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://tp-lake-dev/scripts/iceberg_transactions_job.py"
  }

  default_arguments = {
    "--job-language"        = "python"
    "--datalake-formats"    = "iceberg"
    "--conf"                = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://tp-lake-dev/iceberg --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO"
    "--iceberg_job_catalog_warehouse" = "s3://tp-lake-dev-silver/iceberg"
    "--job-bookmark-option" = "job-bookmark-enable" 
  }
}

resource "aws_s3_bucket_object" "iceberg_bank_accounts_job" {
  bucket = "tp-lake-dev"
  key    = "scripts/iceberg_bank_accounts_job.py"
  etag   = filemd5("${path.module}/iceberg_bank_accounts_job.py")
  source = "${path.module}/iceberg_bank_accounts_job.py"
}

resource "aws_glue_job" "iceberg_bank_accounts_job" {
  name     = "iceberg_bank_accounts_job" 
  role_arn = aws_iam_role.glue_admin_role.arn
  glue_version = "4.0"
  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://tp-lake-dev/scripts/iceberg_bank_accounts_job.py"
  }

  default_arguments = {
    "--job-language"        = "python"
    "--datalake-formats"    = "iceberg"
    "--conf"                = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://tp-lake-dev/iceberg --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO"
    "--iceberg_job_catalog_warehouse" = "s3://tp-lake-dev-silver/iceberg"
    "--job-bookmark-option" = "job-bookmark-enable" 
  }
}


