# How to Run Database Script - Simple Guide

## Quick Steps

### 1. Get Information from Terraform

```bash
# Get RDS endpoint
terraform output rds_instance_endpoint

# Get RDS secret ARN (for password)
terraform output rds_master_user_secret_arn

# Get bastion public IP
terraform output bastion_public_ip
```

### 2. Get Database Password

```bash
# Get password from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw rds_master_user_secret_arn) \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password'
```

### 3. Connect to Bastion Host

```bash
# SSH to bastion (use your SSH key)
ssh -i your-key.pem ec2-user@$(terraform output -raw bastion_public_ip)
```

### 4. Run Database Script

Once connected to bastion:

```bash
# Copy the script to bastion (from your local machine)
# In a new terminal window:
scp -i your-key.pem database/schema.sql ec2-user@$(terraform output -raw bastion_public_ip):~/

# Back on bastion, run the script
mysql -h $(terraform output -raw rds_instance_endpoint) -u admin -p UserDB < ~/schema.sql

# Enter password when prompted (from step 2)
```

### 5. Verify

```bash
# Connect to database
mysql -h $(terraform output -raw rds_instance_endpoint) -u admin -p UserDB

# Then run:
SHOW TABLES;
DESCRIBE Employee;
```

## All-in-One Script

Save this as `run-db-script.sh`:

```bash
#!/bin/bash
set -e

# Get values
RDS_ENDPOINT=$(terraform output -raw rds_instance_endpoint)
BASTION_IP=$(terraform output -raw bastion_public_ip)
SECRET_ARN=$(terraform output -raw rds_master_user_secret_arn)
PASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region us-east-1 --query SecretString --output text | jq -r '.password')

# Copy script to bastion
scp -i your-key.pem database/schema.sql ec2-user@$BASTION_IP:~/

# Run script via SSH
ssh -i your-key.pem ec2-user@$BASTION_IP "mysql -h $RDS_ENDPOINT -u admin -p'$PASSWORD' UserDB < ~/schema.sql"

echo "Database script executed successfully!"
```

## Notes

- Replace `your-key.pem` with your actual SSH key file
- RDS is in private subnet - only accessible from bastion
- Credentials are in AWS Secrets Manager (secure)
- MySQL client is pre-installed on bastion host

