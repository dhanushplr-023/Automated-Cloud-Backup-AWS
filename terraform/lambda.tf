# ==============================================================================
# Package the Python Lambda code into a .zip archive automatically
# ==============================================================================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/backup_orchestrator.py"
  output_path = "${path.module}/../lambda/backup_orchestrator.zip"
}

# ==============================================================================
# AWS Lambda Function: Backup Orchestrator
# ==============================================================================
resource "aws_lambda_function" "backup_orchestrator" {
  function_name    = "${var.project_name}-orchestrator"
  description      = "Automates daily EC2 backups via SSM Run Command and polls status"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = "python3.12"
  handler = "backup_orchestrator.lambda_handler"
  role    = aws_iam_role.lambda_orchestrator_role.arn

  timeout     = 300 # 5 minutes (allows SSM command dispatch + polling loop)
  memory_size = 128 # Minimum footprint, eligible for Free Tier

  environment {
    variables = {
      EC2_INSTANCE_ID       = aws_instance.backup_server.id
      BACKUP_SCRIPT_PATH    = "/opt/backup/backup.sh"
      S3_BUCKET_NAME        = aws_s3_bucket.backup_bucket.id
      POLL_INTERVAL_SECONDS = "5"
      MAX_TIMEOUT_SECONDS   = "240"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_ssm_attach,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name    = "${var.project_name}-orchestrator"
    Purpose = "Automated Backup Engine"
  }
}

# ==============================================================================
# Amazon CloudWatch Log Group (With 7-Day Retention to Prevent Storage Costs)
# ==============================================================================
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-orchestrator"
  retention_in_days = 7 # Automatically purges old logs after 7 days

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}
