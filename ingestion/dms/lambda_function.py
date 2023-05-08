import json
import base64
import boto3

s3 = boto3.client('s3')

def lambda_handler(event, context):
    payload = base64.b64decode(event['records'][0]['data'])
    records = json.loads(payload)

    # Process the records
    
    output = []
  
    for record in event['records']:
        new_record = process_record(record)
        output_record = {
            'recordId': record['recordId'],
            'result': 'Ok',
            'data': new_record['data']
        }

        output.append(output_record)

    return {
      'records': output
    }

def process_record(record):
    # Add any processing logic here
    return record


