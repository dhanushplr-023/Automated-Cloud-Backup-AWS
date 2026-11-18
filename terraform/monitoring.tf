# ==============================================================================
# Amazon SNS Topic for Operational Alerts
# ==============================================================================
resource "aws_sns_topic" "backup_alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name    = "${var.project_name}-alerts"
    Purpose = "Cloud Backup Failure Notifications"
  }
}

# Optional Email Subscription (Activated if alert_email is provided)
resource "aws_sns_topic_subscription" "email_subscription" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.backup_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ==============================================================================
# CloudWatch Metric Alarm: Lambda Backup Failure Detection
# Fires whenever Lambda raises an unhandled error or SSM execution fails
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "lambda_failure_alarm" {
  alarm_name          = "${var.project_name}-lambda-failure-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when the automated backup Lambda function encounters an execution failure"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.backup_orchestrator.function_name
  }

  alarm_actions = [aws_sns_topic.backup_alerts.arn]
  ok_actions    = [aws_sns_topic.backup_alerts.arn]

  tags = {
    Name = "${var.project_name}-lambda-failure-alarm"
  }
}

# ==============================================================================
# CloudWatch Metric Alarm: EC2 Health / Status Check Failed
# Triggers if the EC2 backup server experiences hardware/OS failure
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_alarm" {
  alarm_name          = "${var.project_name}-ec2-status-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300 # 5 minutes
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers when the EC2 backup source server fails instance or system status checks"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.backup_server.id
  }

  alarm_actions = [aws_sns_topic.backup_alerts.arn]

  tags = {
    Name = "${var.project_name}-ec2-status-alarm"
  }
}

# ==============================================================================
# CloudWatch Monitoring Dashboard
# Unified single-pane-of-glass dashboard for backup operations
# ==============================================================================
resource "aws_cloudwatch_dashboard" "backup_dashboard" {
  dashboard_name = "${var.project_name}-operations-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Orchestrator - Invocations vs Errors"
          region  = var.aws_region
          stacked = false
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.backup_orchestrator.function_name, { color = "#2ca02c" }],
            [".", "Errors", ".", ".", { color = "#d62728" }]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 Backup Source Server - CPU & Status Check"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.backup_server.id, { color = "#1f77b4" }],
            [".", "StatusCheckFailed", ".", ".", { color = "#ff7f0e" }]
          ]
          period = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title   = "Recent Backup Execution Logs"
          region  = var.aws_region
          query   = "SOURCE '/aws/lambda/${aws_lambda_function.backup_orchestrator.function_name}' | fields @timestamp, @message | sort @timestamp desc | limit 25"
        }
      }
    ]
  })
}
