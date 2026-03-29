#!/bin/bash
set -e

# ----------------------------------------------------------------------------
# TOMCAT INSTANCE USER DATA SCRIPT
# This script pulls WAR file from S3 and deploys to Tomcat
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# STEP 1: SET ENVIRONMENT VARIABLES
# ----------------------------------------------------------------------------
export S3_BUCKET="${s3_bucket}"
export TOMCAT_WEBAPPS_DIR="/usr/share/tomcat/webapps"

echo "Environment variables set:"
echo "  S3_BUCKET: $S3_BUCKET"
echo "  TOMCAT_WEBAPPS_DIR: $TOMCAT_WEBAPPS_DIR"

# ----------------------------------------------------------------------------
# STEP 2: DOWNLOAD WAR FILE FROM S3
# ----------------------------------------------------------------------------
echo "Downloading WAR file from S3..."
cd /tmp
aws s3 cp s3://$S3_BUCKET/app.war /tmp/app.war || {
  echo "Failed to download WAR file from S3"
  exit 1
}

# ----------------------------------------------------------------------------
# STEP 3: DEPLOY WAR TO TOMCAT WEBAPPS
# ----------------------------------------------------------------------------
echo "Deploying WAR file to Tomcat webapps directory..."
cp /tmp/app.war $TOMCAT_WEBAPPS_DIR/ || {
  echo "Failed to copy WAR file to webapps directory"
  exit 1
}

# Set proper permissions
chown tomcat:tomcat $TOMCAT_WEBAPPS_DIR/app.war

# ----------------------------------------------------------------------------
# STEP 4: RESTART TOMCAT
# ----------------------------------------------------------------------------
echo "Restarting Tomcat service..."
systemctl restart tomcat

# Wait for Tomcat to start
sleep 10

# Verify Tomcat is running
systemctl status tomcat || {
  echo "Tomcat failed to start"
  exit 1
}

echo "WAR file deployed and Tomcat restarted successfully!"

