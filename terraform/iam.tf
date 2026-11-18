# ==============================================================================
# 1. IAM ROLE FOR EC2 INSTANCE (Backup Source Server)
# ==============================================================================

# Trust Policy: Allows EC2 service to assume this role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_backup_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# Attach AWS Managed Policy: AmazonSSMManagedInstanceCore
# Required for Systems Manager Agent to connect to AWS Systems Manager without inbound SSH (Port 22)
resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom Least-Privilege S3 Policy for EC2
# Grants only PutObject, GetObject, and ListBucket strictly to our backup bucket
data "aws_iam_policy_document" "ec2_s3_policy_doc" {
  statement {
    sid     = "AllowListBackupBucket"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.backup_bucket.arn
    ]
  }

  statement {
    sid    = "AllowBackupObjectOperations"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.backup_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_s3_policy" {
  name        = "${var.project_name}-ec2-s3-policy"
  description = "Allows EC2 instance to upload and download backups from S3 bucket"
  policy      = data.aws_iam_policy_document.ec2_s3_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
  role       = aws_iam_role.ec2_backup_role.name
  policy_arn = aws_iam_policy.ec2_s3_policy.arn
}

# EC2 Instance Profile (Container that passes the IAM role to the EC2 virtual machine)
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_backup_role.name
}


# ==============================================================================
# 2. IAM ROLE FOR AWS LAMBDA (Automation & Orchestration Engine)
# ==============================================================================

# Trust Policy: Allows Lambda service to assume this role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_orchestrator_role" {
  name               = "${var.project_name}-lambda-orchestrator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${var.project_name}-lambda-orchestrator-role"
  }
}

# Attach AWS Managed Policy: AWSLambdaBasicExecutionRole
# Allows Lambda to create CloudWatch Log Groups, Streams, and write execution logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_orchestrator_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom Least-Privilege SSM Policy for Lambda
# Allows Lambda to send run commands via SSM and poll for execution status
data "aws_iam_policy_document" "lambda_ssm_policy_doc" {
  statement {
    sid    = "AllowSSMRunCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:DescribeInstanceInformation"
    ]
    resources = ["*"] # SSM commands require wildcard or document/instance ARNs
  }
}

resource "aws_iam_policy" "lambda_ssm_policy" {
  name        = "${var.project_name}-lambda-ssm-policy"
  description = "Allows Lambda to execute and monitor SSM commands on EC2"
  policy      = data.aws_iam_policy_document.lambda_ssm_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_ssm_attach" {
  role       = aws_iam_role.lambda_orchestrator_role.name
  policy_arn = aws_iam_policy.lambda_ssm_policy.arn
}
