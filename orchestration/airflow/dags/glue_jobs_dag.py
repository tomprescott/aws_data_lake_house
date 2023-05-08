from datetime import timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.glue import AwsGlueJobOperator
from airflow.utils.dates import days_ago

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'glue_jobs_dag',
    default_args=default_args,
    description='DAG to run AWS Glue jobs',
    schedule_interval=timedelta(days=1),
    start_date=days_ago(1),
    tags=['glue'],
)

glue_job_names = [
    "iceberg_customers_job",
    "iceberg_bank_accounts_job",
    "iceberg_transactions_job",
]

for job_name in glue_job_names:
    task = AwsGlueJobOperator(
        task_id=f"{job_name}_task",
        job_name=job_name,
        aws_conn_id='aws_default',
        region_name='eu-west-2',
        dag=dag,
    )
