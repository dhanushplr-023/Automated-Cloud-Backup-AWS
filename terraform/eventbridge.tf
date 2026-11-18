# ==============================================================================
# Amazon EventBridge Scheduled Rule (Daily Backup Trigger)
# ==============================================================================
resource "aws_cloudwatch_event_rule" "daily_backup_rule" {
  name                = "${var.project_name}-daily-schedule"
  description         = "Fires daily at 02:00 UTC to trigger automated EC2 cloud backup"
  schedule_expression = "cron(0 2 * * ? *)" # Runs every day at 02:00 AM UTC (07:30 AM IST)

  tags = {
    Name    = "${var.project_name}-daily-schedule"
    Purpose = "Automated Daily Backup Schedule"
  }
}

# ==============================================================================
# EventBridge Target: Connect Rule to Lambda Function
# ==============================================================================
resource "aws_cloudwatch_event_target" "lambda_backup_target" {
  rule      = aws_cloudwatch_event_rule.daily_backup_rule.name
  target_id = "TriggerLambdaBackupOrchestrator"
  arn       = aws_lambda_function.backup_orchestrator.arn
}

# ==============================================================================
# Lambda Resource-Based Policy
# Grants EventBridge permission to invoke the Lambda function
# ==============================================================================
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_backup_rule.arn
}
