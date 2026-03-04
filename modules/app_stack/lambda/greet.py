import os
import json
import uuid
import time
import boto3

ddb = boto3.resource("dynamodb")
sns = boto3.client("sns")
# Verification topic is always in us-east-1 (cross-account)
sns_us_east = boto3.client("sns", region_name="us-east-1")

TABLE_NAME = os.environ.get("DDB_TABLE")
SNS_ARN = os.environ.get("SNS_ARN")
VERIFICATION_SNS_ARN = os.environ.get("VERIFICATION_SNS_ARN", "")
REGION = os.environ.get("REGION", "unknown")
EMAIL = os.environ.get("EMAIL", "")
GITHUB_REPO = os.environ.get("GITHUB_REPO", "")


def lambda_handler(event, context):
    """
    Greeter Lambda – POST /greet
    1. Writes a record to regional DynamoDB table.
    2. Publishes verification payload to Unleash Live SNS (cross-account).
    3. Publishes to own SNS topic for email notifications.
    4. Returns 200 OK with region name.
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

    # ── Verification payload (required by assessment) ────────
    sns_message = {
        "email": EMAIL,
        "source": "Lambda",
        "region": REGION,
        "repo": GITHUB_REPO,
    }

    # Publish to Unleash Live verification topic (cross-account, us-east-1)
    if VERIFICATION_SNS_ARN:
        try:
            sns_us_east.publish(
                TopicArn=VERIFICATION_SNS_ARN,
                Message=json.dumps(sns_message),
                Subject="Greeter Verification",
            )
            print(f"[INFO] Verification SNS published for region={REGION}")
        except Exception as e:
            print(f"[ERROR] Verification SNS publish failed: {e}")

    # Publish to own topic (email notifications)
    if SNS_ARN:
        try:
            sns.publish(
                TopicArn=SNS_ARN,
                Message=json.dumps(sns_message),
                Subject="Greeter Verification",
            )
            print(f"[INFO] Own SNS published for region={REGION}")
        except Exception as e:
            print(f"[ERROR] Own SNS publish failed: {e}")

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
