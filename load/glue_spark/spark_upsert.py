import sys
import json
import urllib
import datetime
import boto3
import time
import logging
from awsglue.utils import getResolvedOptions
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import SQLContext
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from awsglue.context import GlueContext

def load_initial_check(bucket, prefix, lastFullLoadDate, s3conn):
    
    initialfiles = s3conn.list_objects(Bucket=bucket, Prefix=prefix+'/LOAD').get('Contents')
    if initialfiles is not None :
        s3FileTS = initialfiles[0]['LastModified'].replace(tzinfo=None)
        ddbFileTS = datetime.datetime.strptime(lastFullLoadDate, '%Y-%m-%d %H:%M:%S')
        if s3FileTS > ddbFileTS:
            print('Initial file found to be processed')
            loadInitial = True
            lastFullLoadDate = datetime.datetime.strftime(s3FileTS,'%Y-%m-%d %H:%M:%S')
        else:
            loadInitial = False
            print('Intial files already processed')
    else:
        loadInitial = False
        print('No initial files to process')
    return loadInitial, lastFullLoadDate

def load_incremental_check(bucket, prefix, lastIncrementalFile, s3conn):
    
    newIncrementalFile = None
    loadIncremental = False
    incrementalFiles = s3conn.list_objects_v2(Bucket=bucket, Prefix=prefix+'/2', StartAfter=lastIncrementalFile).get('Contents')
    if incrementalFiles is not None:
        filecount = len(incrementalFiles)
        newIncrementalFile = bucket + '/' + incrementalFiles[filecount-1]['Key']
        if newIncrementalFile != lastIncrementalFile:
            loadIncremental = True
            print('Incremental files found to be processed' )
        else:
            print('Incremental files already processed')
    else:
        print('No incremental files to process')
    return loadIncremental, newIncrementalFile

def load_initial(spark, path, s3_inputpath, s3_outputpath, partitionKey, lastFullLoadDate, ddbconn):
    
    input = spark.read.parquet(s3_inputpath+"/LOAD*.parquet").withColumn("Op", lit("I"))
    
    partition_keys = partitionKey
    if partition_keys != "null" :
        print('Begin partition load')
        partitionKeys = partition_keys.split(",")
        partitionCount = input.select(partitionKeys).distinct().count()
        input.repartition(partitionCount,partitionKeys).write.mode('overwrite').partitionBy(partitionKeys).parquet(s3_outputpath)
    else:
        print('Begin load')
        input.write.mode('overwrite').parquet(s3_outputpath)
        
    ddbconn.update_item(
    TableName='DMSCDC_Controller',
    Key={"path": {"S":path}},
    AttributeUpdates={"LastFullLoadDate": {"Value": {"S": lastFullLoadDate}}})
    
def load_incremental(spark, path, bucket, prefix, s3_inputpath, s3_outputpath, lastIncrementalFile, newIncrementalFile, primaryKey, partitionKey, s3conn, ddbconn):
    
    last_file = lastIncrementalFile
    curr_file = newIncrementalFile
    primary_keys = primaryKey
    partition_keys = partitionKey
    
    # gets list of files to process
    inputFileList = []
    results = s3conn.list_objects_v2(Bucket=bucket, Prefix=prefix +'/2', StartAfter=lastIncrementalFile).get('Contents')
    for result in results:
        if (bucket + '/' + result['Key'] != last_file):
            inputFileList.append('s3://' + bucket + '/' + result['Key'])
    
    inputfile = spark.read.parquet(*inputFileList)
    
    tgtExists = True
    try:
        test = spark.read.parquet(s3_outputpath)
    except:
        tgtExists = False
    
    #No Primary_Keys implies insert only
    if primary_keys == "null" or not(tgtExists):
        output = inputfile.filter(inputfile.Op=='I')
        filelist = [["null"]]
    else:
        primaryKeys = primary_keys.split(",")
        windowRow = Window.partitionBy(primaryKeys).orderBy("sortpath")
    
        #Loads the target data adding columns for processing
        target = spark.read.parquet(s3_outputpath).withColumn("sortpath", lit("0")).withColumn("tgt_filepath",input_file_name()).withColumn("rownum", lit(1))
        input = inputfile.withColumn("sortpath", input_file_name()).withColumn("src_filepath",input_file_name()).withColumn("rownum", row_number().over(windowRow))
    
        #determine impacted files
        files = target.join(input, primaryKeys, 'inner').select(col("tgt_filepath").alias("list_filepath")).distinct()
        filelist = files.collect()
    
        uniondata = input.unionByName(target.join(files,files.list_filepath==target.tgt_filepath), allowMissingColumns=True)
        window = Window.partitionBy(primaryKeys).orderBy(desc("sortpath"), desc("rownum"))
        output = uniondata.withColumn('rnk', rank().over(window)).where(col("rnk")==1).where(col("Op")!="D").coalesce(1).select(inputfile.columns)
    
    ddbconn.update_item(
    TableName='DMSCDC_Controller',
    Key={"path": {"S":path}},
    AttributeUpdates={"LastIncrementalFile": {"Value": {"S": newIncrementalFile}}})
    
    # write data by partitions
    if partition_keys != "null" :
        partitionKeys = partition_keys.split(",")
        partitionCount = output.select(partitionKeys).distinct().count()
        output.repartition(partitionCount,partitionKeys).write.mode('append').partitionBy(partitionKeys).parquet(s3_outputpath)
    else:
        output.write.mode('append').parquet(s3_outputpath)
    
    #delete old files
        if row[0] != "null":
            o = parse.urlparse(row[0])
            s3conn.delete_object(Bucket=o.netloc, Key=parse.unquote(o.path)[1:])
            
def run():

    args = getResolvedOptions(sys.argv, ['JOB_NAME', 'bucket', 'out_bucket', 'prefix', 'out_prefix'])
    bucket, out_bucket, prefix, out_prefix = args['bucket'], args['out_bucket'], args['prefix'], args['out_prefix']
    out_path = out_bucket + '/' + out_prefix
    
    sparkContext = SparkContext.getOrCreate()
    glueContext = GlueContext(sparkContext)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args['JOB_NAME'], args)
    
    ddbconn = boto3.client('dynamodb')
    s3conn = boto3.client('s3')
    
    s3_inputpath = 's3://' + bucket + '/' + prefix
    s3_outputpath = 's3://' + out_path
    
    schema = s3conn.list_objects(Bucket=bucket, Prefix=prefix, Delimiter='/').get('CommonPrefixes')
    if schema is None:
        print('s3 location is empty')
        sys.exit()
    
    path = 's3://' + bucket + '/' + prefix
    
    item = {
        'path': {'S':path},
        'bucket': {'S':bucket},
        'prefix': {'S':prefix},
        'PrimaryKey': {'S':'null'},
        'PartitionKey': {'S':'null'},
        'LastFullLoadDate': {'S':'1900-01-01 00:00:00'},
        'LastIncrementalFile': {'S':prefix + '/0.parquet'},
        'out_path': {'S': out_path}}
    
    #Put Item if not already present
    try:
        response = ddbconn.get_item(TableName='DMSCDC_Controller', Key={'path': {'S':path}})
        if 'Item' in response:
            item = response['Item']
        else:
            ddbconn.put_item(TableName='DMSCDC_Controller', Item=item)
    except:
        ddbconn.put_item(TableName='DMSCDC_Controller', Item=item)
    
    
    partitionKey = item['PartitionKey']['S']
    lastFullLoadDate = item['LastFullLoadDate']['S']
    lastIncrementalFile = item['LastIncrementalFile']['S']
    primaryKey = item['PrimaryKey']['S']

    loadInitial, lastFullLoadDate = load_initial_check(bucket, prefix, lastFullLoadDate, s3conn)
    if loadInitial == True:
        load_initial(spark, path, s3_inputpath, s3_outputpath, partitionKey, lastFullLoadDate, ddbconn)
    
    loadIncremental, newIncrementalFile = load_incremental_check(bucket, prefix, lastIncrementalFile, s3conn)
    if loadIncremental == True:
        load_incremental(spark, path, bucket, prefix, s3_inputpath, s3_outputpath, lastIncrementalFile, newIncrementalFile, primaryKey, partitionKey, s3conn, ddbconn)
        
run()        

        
