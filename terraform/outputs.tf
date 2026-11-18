output "s3_bucket_name" {
  description = "The name of the S3 backup bucket"
  value       = aws_s3_bucket.backup_bucket.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 backup bucket"
  value       = aws_s3_bucket.backup_bucket.arn
}

output "ec2_instance_profile_name" {
  description = "IAM instance profile name attached to EC2"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "ec2_role_arn" {
  description = "IAM role ARN attached to EC2"
  value       = aws_iam_role.ec2_backup_role.arn
}

output "lambda_role_arn" {
  description = "IAM role ARN attached to Lambda"
  value       = aws_iam_role.lambda_orchestrator_role.arn
}

output "ec2_instance_id" {
  description = "The EC2 Instance ID of the source server"
  value       = aws_instance.backup_server.id
}

output "ec2_security_group_id" {
  description = "Security Group ID of the EC2 instance"
  value       = aws_security_group.ec2_backup_sg.id
}

output "lambda_function_name" {
  description = "Name of the Lambda backup orchestrator function"
  value       = aws_lambda_function.backup_orchestrator.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda backup orchestrator function"
  value       = aws_lambda_function.backup_orchestrator.arn
}

output "eventbridge_schedule_rule" {
  description = "EventBridge daily schedule rule name"
  value       = aws_cloudwatch_event_rule.daily_backup_rule.name
}

output "eventbridge_cron_expression" {
  description = "The cron expression for daily backup"
  value       = aws_cloudwatch_event_rule.daily_backup_rule.schedule_expression
}

output "sns_alerts_topic_arn" {
  description = "ARN of the SNS topic for backup failure alerts"
  value       = aws_sns_topic.backup_alerts.arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch operations dashboard"
  value       = aws_cloudwatch_dashboard.backup_dashboard.dashboard_name
}
