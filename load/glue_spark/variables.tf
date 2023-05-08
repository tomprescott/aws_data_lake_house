variable "bucket" {
  description = "The name of the input S3 bucket"
}

variable "out_bucket" {
  description = "The name of the output S3 bucket"
}

variable "prefix" {
  description = "The prefix for the input S3 objects"
}

variable "out_prefix" {
  description = "The prefix for the output S3 objects"
}

variable "glue_role" {
  description = "The iam role for the glue script"
}

variable "table_name" {
  description = "The name of the souce table, used to generate the job name"
}
