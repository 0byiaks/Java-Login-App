#!/bin/bash
set -e

# ----------------------------------------------------------------------------
# BASTION HOST USER DATA SCRIPT
# This script automatically sets up the database schema on RDS
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# STEP 1: SET ENVIRONMENT VARIABLES
# ----------------------------------------------------------------------------
export RDS_ENDPOINT="${rds_endpoint}"
export RDS_SECRET_ARN="${rds_secret_arn}"
export AWS_REGION="${aws_region}"
export S3_BUCKET_URI="${s3_bucket_uri}"
export DB_NAME="UserDB"
export DB_USERNAME="admin"

echo "Environment variables set:"
echo "  RDS_ENDPOINT: $RDS_ENDPOINT"
echo "  AWS_REGION: $AWS_REGION"
echo "  S3_BUCKET_URI: $S3_BUCKET_URI"
echo "  DB_NAME: $DB_NAME"
echo "  DB_USERNAME: $DB_USERNAME"

# ----------------------------------------------------------------------------
# STEP 2: INSTALL REQUIRED TOOLS
# ----------------------------------------------------------------------------
echo "Installing MySQL client and AWS CLI..."
yum update -y
yum install -y mysql aws-cli jq

# ----------------------------------------------------------------------------
# STEP 3: WAIT FOR RDS TO BE READY
# ----------------------------------------------------------------------------
echo "Waiting for RDS to be ready..."
sleep 120

# ----------------------------------------------------------------------------
# STEP 4: DOWNLOAD SQL SCRIPT FROM S3
# ----------------------------------------------------------------------------
echo "Downloading schema.sql from S3..."
aws s3 cp $S3_BUCKET_URI /tmp/schema.sql || {
  echo "Failed to download schema.sql from S3: $S3_BUCKET_URI"
  exit 1
}

# ----------------------------------------------------------------------------
# STEP 5: GET DATABASE CREDENTIALS FROM SECRETS MANAGER
# ----------------------------------------------------------------------------
echo "Getting database credentials from Secrets Manager..."
SECRET=$(aws secretsmanager get-secret-value --secret-id "$RDS_SECRET_ARN" --region "$AWS_REGION" --query SecretString --output text)
DB_PASSWORD=$(echo "$SECRET" | jq -r '.password')

if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: Could not read .password from secret $RDS_SECRET_ARN"
  exit 1
fi
echo "RDS password fetched OK"

# Write password to MySQL config file to avoid # being treated as comment
# by the MySQL config file parser when password contains # characters.
printf '[client]\npassword="%s"\n' "$DB_PASSWORD" > /tmp/.my.cnf
chmod 600 /tmp/.my.cnf

# ----------------------------------------------------------------------------
# STEP 6: RUN SQL SCRIPT ON RDS
# ----------------------------------------------------------------------------
# Connect without specifying a database — schema.sql handles CREATE DATABASE + USE UserDB
echo "Running database schema script on RDS..."
mysql --defaults-extra-file=/tmp/.my.cnf -h "$RDS_ENDPOINT" -u "$DB_USERNAME" < /tmp/schema.sql || {
  echo "Failed to execute SQL script"
  rm -f /tmp/.my.cnf
  exit 1
}
rm -f /tmp/.my.cnf

# ----------------------------------------------------------------------------
# STEP 6: SIGNAL COMPLETION
# ----------------------------------------------------------------------------
echo "Database schema script executed successfully!"
touch /tmp/db-schema-complete

