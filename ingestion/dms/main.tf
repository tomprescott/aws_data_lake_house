resource "aws_s3_bucket" "tp_lake_dev" {
  bucket = "tp-lake-dev-bronze"
}

resource "aws_iam_policy" "dms_s3_access" {
  name = "dms_s3_access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:CreateBucket",
          "s3:ListBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Effect = "Allow"
        Resource = [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "dms_s3_role" {
  name = "dms_s3_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_s3_role_policy_attachment" {
  policy_arn = aws_iam_policy.dms_s3_access.arn
  role = aws_iam_role.dms_s3_role.name
}

resource "aws_dms_replication_instance" "tp_dms" {
  replication_instance_id = "tp-dms-replication-instance"
  replication_instance_class      = "dms.t2.micro"
  allocated_storage               = 20
  vpc_security_group_ids          = [var.db_sg_id]
  engine_version                  = "3.4.6"
}

resource "aws_dms_endpoint" "tp_pg_source_endpoint" {
  endpoint_id = "tp-postgres-source-endpoint"
  endpoint_type = "source"
  engine_name = "postgres"
  username = var.rds_username
  password = var.rds_password
  server_name = var.server_name
  port = 5432
  database_name = var.db_name
}

resource "aws_dms_endpoint" "tp_s3_target_endpoint" { 
  endpoint_id = "tp-s3-target-endpoint"
  endpoint_type = "target"
  engine_name = "s3"

  s3_settings {
    bucket_folder = "dms-data"
    bucket_name = aws_s3_bucket.tp_lake_dev.id
    data_format = "parquet"
    service_access_role_arn = aws_iam_role.dms_s3_role.arn
    timestamp_column_name = "dms_timestamp"
  }
}

resource "aws_dms_replication_task" "dms_replication_task" {
  replication_task_id = "tp-lake-dms-postgres-replication-task"
  source_endpoint_arn = aws_dms_endpoint.tp_pg_source_endpoint.endpoint_arn
  target_endpoint_arn = aws_dms_endpoint.tp_s3_target_endpoint.endpoint_arn
  replication_instance_arn = aws_dms_replication_instance.tp_dms.replication_instance_arn
  migration_type = "full-load-and-cdc"
  replication_task_settings = ""
  #table_mappings = "{ \"rules\": [ { \"rule-type\": \"selection\", \"rule-id\": \"1\", \"rule-name\": \"1\", \"object-locator\": { \"schema-name\": \"%\", \"table-name\": \"%\" }, \"rule-action\": \"include\" } ] }"
  table_mappings = jsonencode({
    "rules": [
      {
        "rule-type": "selection",
        "rule-id": "1",
        "rule-name": "1",
        "object-locator": {
          "schema-name": "%",
          "table-name": "%"
        },
        "rule-action": "include"
      },
      {
        "rule-type": "transformation",
        "rule-id": "2",
        "rule-name": "2",
        "rule-action": "add-column"
        "rule-target": "column",
        "object-locator": {
          "schema-name": "%",
          "table-name": "%"
        },
        "rule-target": "column",
        "value": "cdc_timestamp"
        "expression": "$AR_H_TIMESTAMP"
        "data-type": {
          "type": "datetime",
          "precision": 6
        }
      },
      {
        "rule-type": "transformation",
        "rule-id": "3",
        "rule-name": "3",
        "rule-action": "add-column"
        "rule-target": "column",
        "object-locator": {
          "schema-name": "%",
          "table-name": "%"
        },
        "rule-target": "column",
        "value": "cdc_operation"
        "expression": "$AR_H_OPERATION"
        "data-type": {
          "type": "string",
          "length": 50 
        }
      }
    ]
  })

  lifecycle {
	  ignore_changes = ["replication_task_settings"]
  }

}

resource "aws_kinesis_stream" "tp_kinesis_stream" {
  name             = "tp-kinesis-stream"
  shard_count      = 1
}

resource "aws_dms_endpoint" "tp_kinesis_target_endpoint" {
  endpoint_id      = "tp-kinesis-target-endpoint"
  endpoint_type    = "target"
  engine_name      = "kinesis"
  kinesis_settings {
    message_format = "json"
    stream_arn     = aws_kinesis_stream.tp_kinesis_stream.arn
    service_access_role_arn = "arn:aws:iam::377435125499:role/dms-admin"
  }
}

resource "aws_dms_replication_task" "dms_replication_task_to_kinesis" {
  replication_task_id        = "tp-lake-dms-postgres-to-kinesis-replication-task"
  source_endpoint_arn        = aws_dms_endpoint.tp_pg_source_endpoint.endpoint_arn
  target_endpoint_arn        = aws_dms_endpoint.tp_kinesis_target_endpoint.endpoint_arn
  replication_instance_arn   = aws_dms_replication_instance.tp_dms.replication_instance_arn
  migration_type             = "full-load-and-cdc"
  replication_task_settings  = ""
  table_mappings             = "{ \"rules\": [ { \"rule-type\": \"selection\", \"rule-id\": \"1\", \"rule-name\": \"1\", \"object-locator\": { \"schema-name\": \"%\", \"table-name\": \"account_activity_log\" }, \"rule-action\": \"include\" } ] }"

  lifecycle {
    ignore_changes = ["replication_task_settings"]
  }
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose_delivery_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "firehose_policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.tp_lake_dev.arn}",
          "${aws_s3_bucket.tp_lake_dev.arn}/*"
        ]
      },
      {
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords"
        ]
        Effect = "Allow"
        Resource = "${aws_kinesis_stream.tp_kinesis_stream.arn}"
      },
      {
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "tp_firehose_stream_account_activity_log" {
  name        = "tp-firehose-delivery-stream"
  destination = "extended_s3"

  extended_s3_configuration {

    bucket_arn = aws_s3_bucket.tp_lake_dev.arn
    role_arn   = aws_iam_role.firehose_role.arn

    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.tp_firehose_processor.arn
        }

        parameters {
          parameter_name  = "NumberOfRetries"
          parameter_value = "3"
        }

        parameters {
          parameter_name  = "RoleArn"
          parameter_value = aws_iam_role.firehose_role.arn
        }
      }
    }
  }
  
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.tp_kinesis_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
}

resource "aws_lambda_function" "tp_firehose_processor" {
  function_name    = "tpFirehoseProcessor"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60
  memory_size      = 128
  source_code_hash = filebase64sha256("${path.module}/firehose_lambda_payload.zip")
  filename         = "${path.module}/firehose_lambda_payload.zip"

  role = aws_iam_role.tp_lambda_role.arn
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_permission" "allow_firehose" {
  statement_id  = "AllowFirehoseInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tp_firehose_processor.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.tp_firehose_stream_account_activity_log.arn
  source_account = data.aws_caller_identity.current.account_id
}

# IAM role for Lambda function
resource "aws_iam_role" "tp_lambda_role" {
  name = "tp_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service =  "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "tp_lambda_policy" {
  name = "tp_lambda_policy"
  role = aws_iam_role.tp_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:*"
        ]
        Effect = "Allow"
        Resource = [
          "*"
        ]
      }
    ]
  })
}
