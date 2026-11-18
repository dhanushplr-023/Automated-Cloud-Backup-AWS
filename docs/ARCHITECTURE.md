# System Architecture & Technical Specifications

## 1. Architectural Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    participant EB as Amazon EventBridge
    participant LM as AWS Lambda (Python 3.12)
    participant SSM as AWS Systems Manager
    participant EC2 as Amazon EC2 (AL2023)
    participant S3 as Amazon S3 Vault
    participant CW as Amazon CloudWatch Logs / Alarms
    participant SNS as Amazon SNS

    Note over EB: Daily Schedule Trigger (02:00 UTC)
    EB->>LM: Invoke backup_orchestrator
    LM->>SSM: DescribeInstanceInformation (Pre-flight check)
    SSM-->>LM: Instance Online
    LM->>SSM: SendCommand (AWS-RunShellScript: /opt/backup/backup.sh)
    SSM-->>LM: CommandId Issued

    loop Every 5 Seconds (Max 240s)
        LM->>SSM: GetCommandInvocation(CommandId, InstanceId)
        SSM-->>LM: Status (InProgress / Success / Failed)
    end

    SSM->>EC2: Execute backup.sh via SSM Agent
    Note over EC2: 1. tar -czf backup.tar.gz<br/>2. sha256sum<br/>3. tar -tzf verification
    EC2->>S3: aws s3 cp (Archive + Checksum)
    S3-->>EC2: Upload Confirmed

    alt Backup Succeeded
        SSM-->>LM: Status = Success + stdout
        LM->>CW: Log stdout execution transcript
        LM-->>EB: 200 OK (Execution Summary)
    else Backup Failed
        SSM-->>LM: Status = Failed + stderr
        LM->>CW: Log error trace & Raise Exception
        CW->>SNS: Trigger Lambda Failure Alarm (Errors >= 1)
        SNS-->>SNS: Email Notification to DevOps Team
    end
```

---

## 2. Least-Privilege IAM Permission Matrix

| Identity / Role | Associated Policy | Actions Permitted | Target Resource Scope | Security Justification |
| :--- | :--- | :--- | :--- | :--- |
| **EC2 Instance Role** | `AmazonSSMManagedInstanceCore` | `ssm:UpdateInstanceInformation`, `ssmmessages:*` | Outbound endpoints | Allows SSM Agent communication without opening Port 22 (SSH). |
| **EC2 Instance Role** | `cloud-backup-ec2-s3-policy` | `s3:PutObject`, `s3:GetObject`, `s3:ListBucket` | `arn:aws:s3:::cloud-backup-vault-*` | Allows uploading backups and downloading during restore drills. No bucket deletion or cross-bucket permissions. |
| **Lambda Role** | `AWSLambdaBasicExecutionRole` | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` | `/aws/lambda/cloud-backup-orchestrator` | Logs script stdout/stderr and polling metrics to CloudWatch. |
| **Lambda Role** | `cloud-backup-lambda-ssm-policy` | `ssm:SendCommand`, `ssm:GetCommandInvocation`, `ssm:DescribeInstanceInformation` | `AWS-RunShellScript`, Instances | Dispatches backup shell script and polls execution status. |
| **EventBridge Service** | Lambda Resource Policy | `lambda:InvokeFunction` | `cloud-backup-orchestrator` | Triggers function strictly based on the scheduled daily rule. |

---

## 3. Resilience & Disaster Recovery Design

### Backup Integrity Guarantee
- Before uploading, `tar -tzf` validates that the archive table of contents is uncorrupted.
- `sha256sum` generates a cryptographic fingerprint uploaded alongside the `.tar.gz` archive as `.tar.gz.sha256`.
- Restoration executes `sha256sum --check` before decompressing files, preventing corrupt or truncated data from overwriting production state.

### S3 Storage Durability & Security
- **Durability:** 99.999999999% (11 9's) across multiple Availability Zones in `ap-south-1`.
- **Encryption at Rest:** Server-Side Encryption with Amazon S3 Managed Keys (`AES256`).
- **Access Control:** S3 Block Public Access enforces strict zero-trust boundary.
- **Cost Protection:** Automatic 14-day lifecycle expiration rule ensures storage never exceeds the 5 GB AWS Free Tier limit.
