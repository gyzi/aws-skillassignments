import json

def lambda_handler(event, context):
    # A simple placeholder for /dispatch - returns a 200 OK with received body
    try:
        body = event.get('body')
        data = json.loads(body) if body else {}
    except Exception:
        data = {'raw_body': event.get('body')}

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'status': 'dispatched', 'received': data})
    }
