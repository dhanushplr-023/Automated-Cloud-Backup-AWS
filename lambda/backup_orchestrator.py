"""
AWS Lambda Backup Orchestrator
Runtime: Python 3.12
Purpose: Orchestrates daily backups on EC2 via AWS Systems Manager (SSM)
         and monitors execution until completion.
"""

import os
import time
import logging
import boto3
from botocore.exceptions import ClientError

# Configure structured logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients using default credential provider (IAM Role)
ssm_client = boto3.client('ssm')

# Environment variables injected by Terraform
EC2_INSTANCE_ID = os.environ.get('EC2_INSTANCE_ID')
BACKUP_SCRIPT_PATH = os.environ.get('BACKUP_SCRIPT_PATH', '/opt/backup/backup.sh')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
POLL_INTERVAL_SECONDS = int(os.environ.get('POLL_INTERVAL_SECONDS', '5'))
MAX_TIMEOUT_SECONDS = int(os.environ.get('MAX_TIMEOUT_SECONDS', '240'))


def verify_instance_managed(instance_id: str) -> bool:
    """Verifies that the target EC2 instance is registered and online in SSM."""
    logger.info(f"Checking SSM status for instance: {instance_id}")
    try:
        response = ssm_client.describe_instance_information(
            Filters=[{'Key': 'InstanceIds', 'Values': [instance_id]}]
        )
        instances = response.get('InstanceInformationList', [])
        if not instances:
            logger.error(f"Instance {instance_id} is not registered in SSM Fleet Manager.")
            return False

        ping_status = instances[0].get('PingStatus')
        logger.info(f"Instance {instance_id} SSM PingStatus: {ping_status}")
        return ping_status == 'Online'
    except ClientError as e:
        logger.error(f"Failed to query SSM instance information: {e}")
        return False


def execute_ssm_command(instance_id: str, script_path: str) -> str:
    """Sends the execution command to the EC2 instance via SSM."""
    logger.info(f"Sending Run Command to {instance_id}: {script_path}")
    response = ssm_client.send_command(
        InstanceIds=[instance_id],
        DocumentName='AWS-RunShellScript',
        DocumentVersion='$DEFAULT',
        Parameters={
            'commands': [
                f"chmod +x {script_path}",
                script_path
            ]
        },
        Comment=f"Automated Cloud Backup triggered by Lambda for {instance_id}",
        TimeoutSeconds=MAX_TIMEOUT_SECONDS
    )
    command_id = response['Command']['CommandId']
    logger.info(f"SSM Command successfully dispatched. Command ID: {command_id}")
    return command_id


def poll_command_execution(command_id: str, instance_id: str) -> dict:
    """Polls SSM until command completes, returns the invocation result."""
    start_time = time.time()
    logger.info(f"Polling command {command_id} every {POLL_INTERVAL_SECONDS}s...")

    while True:
        elapsed = time.time() - start_time
        if elapsed > MAX_TIMEOUT_SECONDS:
            raise TimeoutError(f"Command execution timed out after {elapsed:.1f} seconds")

        try:
            invocation = ssm_client.get_command_invocation(
                CommandId=command_id,
                InstanceId=instance_id
            )
            status = invocation.get('Status')
            logger.info(f"Elapsed: {elapsed:.1f}s | Current Status: {status}")

            if status in ['Pending', 'InProgress', 'Delayed']:
                time.sleep(POLL_INTERVAL_SECONDS)
                continue

            return invocation

        except ClientError as e:
            # Invocation might take a few seconds to appear after send_command
            if 'InvocationDoesNotExist' in str(e):
                logger.info("Invocation not registered yet, retrying...")
                time.sleep(POLL_INTERVAL_SECONDS)
                continue
            raise e


def lambda_handler(event, context):
    """Main Lambda entrypoint."""
    logger.info("=== AUTOMATED BACKUP ORCHESTRATOR STARTED ===")
    logger.info(f"Target EC2 Instance : {EC2_INSTANCE_ID}")
    logger.info(f"Backup Script Path : {BACKUP_SCRIPT_PATH}")
    logger.info(f"Destination Bucket : {S3_BUCKET_NAME}")

    if not EC2_INSTANCE_ID:
        raise ValueError("EC2_INSTANCE_ID environment variable is missing!")

    # 1. Health check: Is EC2 online in SSM?
    if not verify_instance_managed(EC2_INSTANCE_ID):
        error_msg = f"EC2 Instance {EC2_INSTANCE_ID} is NOT online in Systems Manager."
        logger.error(error_msg)
        raise RuntimeError(error_msg)

    # 2. Dispatch command
    command_id = execute_ssm_command(EC2_INSTANCE_ID, BACKUP_SCRIPT_PATH)

    # 3. Poll for completion
    invocation = poll_command_execution(command_id, EC2_INSTANCE_ID)
    final_status = invocation.get('Status')
    stdout = invocation.get('StandardOutputContent', '')
    stderr = invocation.get('StandardErrorContent', '')

    logger.info(f"Command execution finished with status: {final_status}")
    logger.info(f"--- SCRIPT OUTPUT (STDOUT) ---\n{stdout}")

    if stderr:
        logger.warning(f"--- SCRIPT ERRORS (STDERR) ---\n{stderr}")

    # 4. Verify outcome
    if final_status == 'Success':
        logger.info("=== AUTOMATED BACKUP PROCEDURE COMPLETED SUCCESSFULLY ===")
        return {
            'statusCode': 200,
            'body': {
                'message': 'Backup executed and verified successfully.',
                'commandId': command_id,
                'instanceId': EC2_INSTANCE_ID,
                'status': final_status
            }
        }
    else:
        error_details = f"Backup failed on instance {EC2_INSTANCE_ID}. Status: {final_status}. Error: {stderr}"
        logger.error(error_details)
        # Raising an exception ensures CloudWatch metrics and Lambda Errors metric register the failure
        raise RuntimeError(error_details)
