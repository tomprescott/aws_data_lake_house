import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

from pyspark.sql.functions import *
from awsglue.dynamicframe import DynamicFrame

from pyspark.sql.window import Window
from pyspark.sql.functions import rank, max

from pyspark.conf import SparkConf

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'iceberg_job_catalog_warehouse'])
conf = SparkConf()

## Please make sure to pass runtime argument --iceberg_job_catalog_warehouse with value as the S3 path 
conf.set("spark.sql.catalog.job_catalog.warehouse", args['iceberg_job_catalog_warehouse'])
conf.set("spark.sql.catalog.job_catalog", "org.apache.iceberg.spark.SparkCatalog")
conf.set("spark.sql.catalog.job_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
conf.set("spark.sql.catalog.job_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
conf.set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
conf.set("spark.sql.iceberg.handle-timestamp-without-timezone","true")

sc = SparkContext(conf=conf)
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

## Read Input Table
IncrementalInputDyF = glueContext.create_dynamic_frame.from_catalog(database = "iceberg_demo", table_name = "bank_accounts_input", transformation_ctx = "IncrementalInputDyF")
IncrementalInputDF = IncrementalInputDyF.toDF()

if not IncrementalInputDF.rdd.isEmpty():
    ## Apply De-duplication logic on input data, to pickup latest record based on timestamp and operation 
    IDWindowDF = Window.partitionBy(IncrementalInputDF.id).orderBy(IncrementalInputDF.cdc_timestamp).rangeBetween(-sys.maxsize, sys.maxsize)
                  
    # Add new columns to capture first and last OP value and what is the latest timestamp
    inputDFWithTS= IncrementalInputDF.withColumn("max_op_date",max(IncrementalInputDF.cdc_timestamp).over(IDWindowDF))
    
    # Filter out new records that are inserted, then select latest record from existing records and merge both to get deduplicated output 
    NewInsertsDF = inputDFWithTS.filter("cdc_timestamp=max_op_date").filter("cdc_operation='INSERT'")
    UpdateDeleteDf = inputDFWithTS.filter("cdc_timestamp=max_op_date").filter("cdc_operation IN ('UPDATE','DELETE')")
    finalInputDF = NewInsertsDF.unionAll(UpdateDeleteDf)

    # Register the deduplicated input as temporary table to use in Iceberg Spark SQL statements
    finalInputDF.createOrReplaceTempView("incremental_input_data")
    finalInputDF.show()
    
    ## Perform merge operation on incremental input data with MERGE INTO. This section of the code uses Spark SQL to showcase the expressive SQL approach of Iceberg to perform a Merge operation
    IcebergMergeOutputDF = spark.sql("""
    MERGE INTO job_catalog.iceberg_demo.bank_accounts_output t
    USING (
        SELECT 
            cdc_operation, 
            id,
            account_number,
            balance,
            customer_id
        FROM incremental_input_data) s ON t.id = s.id
    WHEN MATCHED AND s.cdc_operation = 'DELETE' THEN DELETE
    WHEN MATCHED THEN UPDATE SET 
        t.account_number = s.account_number,
        t.balance = s.balance,
        t.customer_id = s.customer_id
    WHEN NOT MATCHED THEN INSERT (
        id, 
        account_number,
        balance,
        customer_id
    ) VALUES (
        s.id, 
        s.account_number,
        s.balance,
        s.customer_id
    )
    """)
    job.commit()
