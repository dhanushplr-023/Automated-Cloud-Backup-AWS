# Automated Cloud Backup and Monitoring System Using AWS

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange.svg)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-blue.svg)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-3.12-yellow.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An enterprise-grade, serverless-orchestrated automated cloud backup and disaster recovery solution built on **Amazon Web Services (AWS)** using **Terraform (Infrastructure as Code)**.

---

## 🏗️ Architecture Overview

The system eliminates legacy insecure practices (like exposing SSH Port 22 or storing static access keys on servers) by using a modern **Zero-Trust** security architecture:

```
[ Amazon EventBridge ] (Daily cron schedule: 02:00 UTC)
          │
          ▼
[ AWS Lambda (Python 3.12) ] (Orchestrator & Polling Engine)
          │
          │  1. SendCommand & Poll Status (Every 5s)
          ▼
[ AWS Systems Manager (SSM) ]
          │
          │  2. Outbound TLS Execution via SSM Agent (No SSH / Port 22)
          ▼
[ Amazon EC2 (Amazon Linux 2023) ]
     - Creates compressed archive (.tar.gz)
     - Computes & checks SHA-256 integrity hash
     - Uploads archive directly to S3 via IAM Instance Profile
          │
          │  3. SSE-S3 AES-256 Encrypted Transfer
          ▼
[ Amazon S3 Vault ]
     - Block Public Access Enabled
     - Date-partitioned prefixes: s3://bucket/backups/YYYY-MM-DD/
     - 14-day Auto-cleanup Lifecycle Rule
          │
          ▼
[ Amazon CloudWatch ]
     - Centralized execution logs
     - Metric Alarms for Lambda Errors & EC2 Health
     - Real-time Operations Dashboard
     - Amazon SNS Email Alerts for Failure Detection
```

---

## 🌟 Key Features

1. **Zero-Trust Security:** EC2 security group has **0 inbound rules**. Administrative commands flow strictly through AWS Systems Manager over TLS.
2. **Zero Hardcoded Credentials:** EC2 and Lambda use dedicated, least-privilege **IAM Roles & Instance Profiles** with auto-rotating temporary credentials.
3. **Cryptographic Integrity Verification:** Backups calculate and verify **SHA-256 checksums** to guarantee zero data corruption during transit and storage.
4. **Resilient Asynchronous Polling:** The Lambda orchestrator does not fire-and-forget; it actively polls SSM execution status every 5 seconds until confirmed success or failure.
5. **Proactive Failure Detection:** Unhandled script failures raise exceptions that immediately trigger CloudWatch Alarms and Amazon SNS email notifications.
6. **Automated Lifecycle & Cost Control:** Old backup archives automatically expire after 14 days, guaranteeing full compliance with AWS Free Tier limits.
7. **Tested Disaster Recovery:** Includes a complete restoration procedure (`restore.sh`) verifying checksums and recovering files from S3 to disk.

---

## 📁 Repository Structure

```text
aws-cloud-backup/
├── terraform/                   # Infrastructure as Code (Terraform)
│   ├── providers.tf             # AWS, Random & Archive provider setup
│   ├── variables.tf             # Configurable variables
│   ├── s3.tf                    # S3 backup bucket, encryption & lifecycle rules
│   ├── iam.tf                   # Least-privilege IAM roles & instance profiles
│   ├── ec2.tf                   # Amazon Linux 2023 with zero-inbound security group
│   ├── lambda.tf                # Python 3.12 orchestrator & CloudWatch log group
│   ├── eventbridge.tf           # Daily cron schedule rule & Lambda permissions
│   ├── monitoring.tf            # CloudWatch alarms, SNS topic & executive dashboard
│   └── outputs.tf               # Terraform output attributes
├── scripts/                     # Linux Automation Scripts
│   ├── backup.sh                # EC2 backup script (tar, gzip, sha256, S3 upload)
│   ├── restore.sh               # Disaster recovery script (download, sha256 check, extract)
│   ├── ssm_deploy_backup.json   # SSM command manifest for backup deployment
│   └── ssm_restore_backup.json  # SSM command manifest for restore drill
├── lambda/                      # Serverless Orchestration
│   └── backup_orchestrator.py   # Python 3.12 handler with SSM polling & error capture
└── docs/                        # Project Documentation
    ├── ARCHITECTURE.md          # Architectural deep-dive and security matrix
    └── CAREER_PORTFOLIO.md      # Resume bullets & LinkedIn publication text
```

---

## 🚀 Quickstart Deployment

### Prerequisites
- AWS Account configured with an active region (e.g., `ap-south-1`).
- [AWS CLI v2](https://aws.amazon.com/cli/) configured via `aws configure`.
- [Terraform v1.5+](https://www.terraform.io/) installed.

### 1. Deploy Infrastructure with Terraform
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 2. Deploy Backup Script to EC2
```powershell
aws ssm send-command --cli-input-json file://../scripts/ssm_deploy_backup.json --region ap-south-1
```

### 3. Test Manual Backup Execution via Lambda
```powershell
aws lambda invoke --function-name "cloud-backup-orchestrator" --region ap-south-1 response.json
cat response.json
```

### 4. Perform a Disaster Recovery Drill
```powershell
aws ssm send-command --cli-input-json file://../scripts/ssm_restore_backup.json --region ap-south-1
```

---

## 🧹 Cost Management & Teardown

To avoid incurring any ongoing AWS charges when you finish testing:

```bash
cd terraform
terraform destroy -auto-approve
```
*Terraform will cleanly terminate the EC2 server, remove IAM roles, delete the Lambda function, remove CloudWatch alarms, and tear down the S3 bucket safely.*

---

## 👤 Author
Developed by **Cloud & DevOps Engineer** as part of the hands-on AWS Production Infrastructure Series.
