data "aws_iam_policy_document" "mwaa_custom_policy_document" {
  statement {
    actions = [
      "glue:StartJobRun",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:BatchStopJobRun",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::tp-lake-dev/*",
      "arn:aws:s3:::tp-lake-dev",
    ]
  }
}

resource "aws_iam_policy" "mwaa_custom_policy" {
  name        = "tp-mwaa-custom-policy"
  description = "A custom policy for your MWAA environment"
  policy      = data.aws_iam_policy_document.mwaa_custom_policy_document.json
}


module "mwaa" {
  source = "aws-ia/mwaa/aws"
  
  name                  = "tp-airflow"
  vpc_id                = var.vpc_id
  private_subnet_ids    = var.subnet_ids
  create_iam_role       = true
  iam_role_additional_policies = [aws_iam_policy.mwaa_custom_policy.arn]
  create_s3_bucket      = true
  dag_s3_path           = "dags"
  requirements_s3_path  = "requirements.txt"
  source_bucket_name    = "airflow-tp-lake"
}

resource "aws_s3_bucket_object" "glue_jobs_dag" {
  key    = "${path.module}dags/glue_jobs_dag.py"
  bucket = module.mwaa.aws_s3_bucket_name
  source = "${path.module}/dags/glue_jobs_dag.py"
}

