import os
import json
import boto3

ecs = boto3.client("ecs")


def lambda_handler(event, context):
    """
    Dispatcher Lambda – POST /dispatch
    Launches a one-shot Fargate task that publishes a message to SNS
    via the amazon/aws-cli container.
    """
    # ── Parse request body ───────────────────────────────────
    try:
        body = event.get("body")
        payload = json.loads(body) if body else {}
    except (json.JSONDecodeError, TypeError):
        payload = {"raw_body": event.get("body")}

    # ── Read ECS configuration from environment ──────────────
    cluster = os.environ.get("ECS_CLUSTER")
    task_def = os.environ.get("ECS_TASK_DEF")
    subnets = [s for s in os.environ.get("PUBLIC_SUBNETS", "").split(",") if s]
    sg = os.environ.get("ECS_SG")
    region = os.environ.get("REGION", "unknown")

    if not all([cluster, task_def, subnets, sg]):
        print("[ERROR] Missing ECS environment configuration")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Missing ECS environment configuration"}),
        }

    # ── Launch Fargate task with MESSAGE override ────────────
    message_str = json.dumps(payload)

    try:
        resp = ecs.run_task(
            cluster=cluster,
            taskDefinition=task_def,
            launchType="FARGATE",
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets": subnets,
                    "securityGroups": [sg],
                    "assignPublicIp": "ENABLED",
                }
            },
            overrides={
                "containerOverrides": [
                    {
                        "name": "aws-cli",
                        "environment": [
                            {"name": "MESSAGE", "value": message_str},
                        ],
                    }
                ]
            },
        )

        # Extract serialisable info from the RunTask response
        tasks = resp.get("tasks", [])
        task_arns = [t.get("taskArn", "") for t in tasks]
        failures = resp.get("failures", [])

        print(f"[INFO] Fargate task launched in {region}: {task_arns}")

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {
                    "message": "Fargate task launched",
                    "region": region,
                    "taskArns": task_arns,
                    "failures": failures,
                }
            ),
        }

    except Exception as e:
        print(f"[ERROR] ECS RunTask failed: {e}")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e), "region": region}),
        }
