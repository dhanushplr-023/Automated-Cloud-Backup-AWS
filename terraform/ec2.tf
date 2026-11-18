# ==============================================================================
# Amazon Linux 2023 AMI Lookup
# ==============================================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# Security Group: Zero Inbound Rules (Maximum Security)
# ==============================================================================
resource "aws_security_group" "ec2_backup_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Zero-inbound security group. All management occurs via AWS Systems Manager."

  # No ingress blocks: zero inbound access from the public internet.

  # Outbound access: Allows EC2 to reach AWS Systems Manager, S3, and yum repos over HTTPS
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# ==============================================================================
# Amazon EC2 Instance
# ==============================================================================
resource "aws_instance" "backup_server" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t3.micro" # Free Tier eligible in ap-south-1

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids = [
    aws_security_group.ec2_backup_sg.id
  ]

  # User Data script: Automatically executes as root when the server first boots up
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Update system packages
              dnf update -y

              # 2. Ensure Amazon SSM Agent is enabled and active
              systemctl enable amazon-ssm-agent
              systemctl restart amazon-ssm-agent

              # 3. Create simulated application production directories
              mkdir -p /var/data/important
              mkdir -p /opt/backup/logs

              # 4. Generate sample critical files for backup testing
              cat << 'DATA_EOF' > /var/data/important/database_dump.sql
              -- Simulated Production Database Dump
              -- Created for Automated Cloud Backup System
              CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100), email VARCHAR(100));
              INSERT INTO users VALUES (1, 'Alice Smith', 'alice@example.com');
              INSERT INTO users VALUES (2, 'Bob Jones', 'bob@example.com');
              INSERT INTO users VALUES (3, 'Charlie Brown', 'charlie@example.com');
              DATA_EOF

              cat << 'DATA_EOF' > /var/data/important/application_config.json
              {
                "app_name": "EcommercePlatform",
                "version": "2.4.0",
                "environment": "production",
                "backup_policy": "daily-cloudwatch-orchestrated"
              }
              DATA_EOF

              cat << 'DATA_EOF' > /var/data/important/customers.csv
              id,first_name,last_name,signup_date,status
              101,John,Doe,2026-01-15,active
              102,Jane,Roe,2026-02-20,active
              103,Peter,Parker,2026-03-10,pending
              DATA_EOF

              # 5. Set appropriate permissions
              chmod -R 750 /var/data/important
              chmod -R 750 /opt/backup

              echo "Initialization complete on $(date)" > /opt/backup/setup.log
              EOF

  tags = {
    Name        = "${var.project_name}-source-server"
    Environment = "Dev"
    BackupScope = "Daily"
  }
}
