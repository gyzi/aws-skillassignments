import os
import json
import uuid
import time
import boto3

ddb = boto3.resource("dynamodb")
sns = boto3.client("sns")

TABLE_NAME = os.environ.get("DDB_TABLE")
SNS_ARN = os.environ.get("SNS_ARN")
REGION = os.environ.get("REGION", "unknown")
EMAIL = os.environ.get("EMAIL", "")
GITHUB_REPO = os.environ.get("GITHUB_REPO", "")


def lambda_handler(event, context):
    """
    Greeter Lambda – POST /greet
    1. Writes a record to regional DynamoDB table.
    2. Publishes a verification payload to SNS.
    3. Returns 200 with the region name.
    """
    # ── Parse request body ───────────────────────────────────
    try:
        body = event.get("body")
        payload = json.loads(body) if body else {}
    except (json.JSONDecodeError, TypeError):
        payload = {"raw_body": event.get("body")}

    # ── Write to DynamoDB ────────────────────────────────────
    record_id = str(uuid.uuid4())
    ts = int(time.time())

    item = {
        "id": record_id,
        "region": REGION,
        "payload": json.dumps(payload),
        "created_at": str(ts),
    }

    if TABLE_NAME:
        table = ddb.Table(TABLE_NAME)
        try:
            table.put_item(Item=item)
        except Exception as e:
            print(f"[ERROR] DynamoDB put_item failed: {e}")

    # ── Publish verification message to SNS ──────────────────
    # Payload format as required by the assessment spec
    sns_message = {
        "email": EMAIL,
        "source": "Lambda",
        "region": REGION,
        "repo": GITHUB_REPO,
    }

    if SNS_ARN:
        try:
            sns.publish(
                TopicArn=SNS_ARN,
                Message=json.dumps(sns_message),
                Subject="Greeter Verification",
            )
            print(f"[INFO] SNS verification published for region={REGION}")
        except Exception as e:
            print(f"[ERROR] SNS publish failed: {e}")

    # ── Return response with region ──────────────────────────
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Greeting recorded",
                "id": record_id,
                "region": REGION,
                "status": "ok",
            }
        ),
    }
