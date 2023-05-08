#CreateTable if not already present
try:
    response1 = ddbconn.describe_table(TableName='DMSCDC_Controller')
except Exception as e:
    ddbconn.create_table(
        TableName='DMSCDC_Controller',
        KeySchema=[{'AttributeName': 'path','KeyType': 'HASH'}],
        AttributeDefinitions=[{'AttributeName': 'path','AttributeType': 'S'}],
        BillingMode='PAY_PER_REQUEST')
    time.sleep(10)
