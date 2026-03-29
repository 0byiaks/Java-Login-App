# Database Setup Guide

## Overview
This directory contains the database schema for the Java Login App.

## Files
- `schema.sql` - Database schema script to create UserDB and Employee table

## How to Run the Database Script

### Step 1: Get RDS Endpoint and Credentials

```bash
# Get RDS endpoint
terraform output rds_instance_endpoint

# Get RDS secret ARN
terraform output rds_master_user_secret_arn

# Get database credentials from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id <secret-arn> \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password'
```

### Step 2: Connect to Bastion Host

```bash
# Get bastion public IP
terraform output bastion_public_ip

# SSH to bastion (replace with your key)
ssh -i your-key.pem ec2-user@<bastion-public-ip>
```

### Step 3: Connect to RDS from Bastion

```bash
# On the bastion host, connect to RDS
mysql -h <rds-endpoint> -u admin -p

# Enter password when prompted (from Secrets Manager)
```

### Step 4: Run the Schema Script

```bash
# Option 1: Run script directly
mysql -h <rds-endpoint> -u admin -p UserDB < /path/to/schema.sql

# Option 2: Copy script to bastion and run
# First, copy schema.sql to bastion:
scp -i your-key.pem database/schema.sql ec2-user@<bastion-public-ip>:~/

# Then on bastion:
mysql -h <rds-endpoint> -u admin -p UserDB < ~/schema.sql
```

### Step 5: Verify

```sql
USE UserDB;
SHOW TABLES;
DESCRIBE Employee;
```

## Quick Reference

- **Database Name**: UserDB
- **Table Name**: Employee
- **RDS Port**: 3306
- **Connection**: From bastion host only (RDS is in private subnet)

## Security Notes

- RDS is in private subnet - not publicly accessible
- Access only via bastion host or through Transit Gateway
- Credentials are managed by AWS Secrets Manager
- Never hardcode credentials in application code

