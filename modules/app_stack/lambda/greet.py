import os
import json
import uuid
import time
import boto3

ddb = boto3.resource('dynamodb')
sns = boto3.client('sns')

TABLE_NAME = os.environ.get('DDB_TABLE')
SNS_ARN = os.environ.get('SNS_ARN')
REGION = os.environ.get('REGION')

def lambda_handler(event, context):
    # Expecting JSON body
    try:
        body = event.get('body')
        if body:
            payload = json.loads(body)
        else:
            payload = {}
    except Exception:
        payload = { 'raw_body': event.get('body') }

    record_id = str(uuid.uuid4())
    ts = int(time.time())

    item = {
        'id': record_id,
        'payload': json.dumps(payload),
        'created_at': str(ts)
    }

    # write to DynamoDB
    if TABLE_NAME:
        table = ddb.Table(TABLE_NAME)
        try:
            table.put_item(Item=item)
        except Exception as e:
            print(f"DynamoDB put_item failed: {e}")

    # publish to SNS
    message = {
        'id': record_id,
        'region': REGION,
        'payload': payload,
        'created_at': ts
    }

    if SNS_ARN:
        try:
            sns.publish(TopicArn=SNS_ARN, Message=json.dumps(message), Subject='greet')
        except Exception as e:
            print(f"SNS publish failed: {e}")

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'id': record_id, 'status': 'ok'})
    }
