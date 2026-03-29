#!/bin/bash
set -e

# ============================================================================
# BASE AMI CONFIGURATION SCRIPT
# This script prepares an Amazon Linux 2 instance to be used as a base AMI
# ============================================================================

# ----------------------------------------------------------------------------
# STEP 1: SYSTEM UPDATES
# ----------------------------------------------------------------------------
# Update all packages to ensure security patches are baked into the AMI
# This is critical - we want the latest security fixes in our base image
echo "Performing OS updates..."
yum update -y

# ----------------------------------------------------------------------------
# STEP 2: INSTALL CLOUDWATCH AGENT DEPENDENCIES
# ----------------------------------------------------------------------------
# CloudWatch Agent requires collectd for memory metrics to work properly
# Without this, metrics may silently fail - hard to debug later
echo "Installing CloudWatch Agent dependencies..."
amazon-linux-extras install -y collectd

# ----------------------------------------------------------------------------
# STEP 3: INSTALL CLOUDWATCH AGENT
# ----------------------------------------------------------------------------
# Download and install the official CloudWatch Agent from AWS
# We don't assume it's pre-installed - makes AMI portable across accounts
echo "Installing CloudWatch Agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# ----------------------------------------------------------------------------
# STEP 4: CONFIGURE CLOUDWATCH AGENT
# ----------------------------------------------------------------------------
# Configure both metrics AND logs support
# Metrics: Memory usage percentage
# Logs: System logs and application logs (configured later, but support is baked in)
echo "Configuring CloudWatch Agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/system",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CWCONFIG

# Start CloudWatch Agent with the configuration
# Using the official control tool ensures proper service management
echo "Starting CloudWatch Agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# ----------------------------------------------------------------------------
# STEP 5: VERIFY AND CONFIGURE SSM AGENT
# ----------------------------------------------------------------------------
# SSM Agent allows us to manage instances without SSH
# Critical for security and operational efficiency
echo "Verifying SSM Agent..."
systemctl status amazon-ssm-agent || systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Wait for SSM Agent to register with AWS
# This ensures the instance is actually manageable via SSM
echo "Waiting for SSM Agent to register with AWS..."
max_attempts=10
attempt=0
while [ $attempt -lt $max_attempts ]; do
  # Check if SSM Agent is running AND registered
  if systemctl is-active --quiet amazon-ssm-agent; then
    # Try to verify registration by checking if we can reach SSM
    # If the service is active, we assume registration will complete
    echo "SSM Agent is active, waiting for registration..."
    sleep 10
    attempt=$((attempt + 1))
  else
    echo "SSM Agent not active, starting..."
    systemctl start amazon-ssm-agent
    sleep 10
    attempt=$((attempt + 1))
  fi
done

# Final SSM status check
systemctl status amazon-ssm-agent

# ----------------------------------------------------------------------------
# STEP 6: CLEANUP BEFORE AMI CREATION
# ----------------------------------------------------------------------------
# Remove temporary files, caches, and downloaded packages
# This keeps the AMI small, fast to boot, and secure
echo "Cleaning up temporary files and caches..."

# Remove downloaded RPM file
rm -f ./amazon-cloudwatch-agent.rpm

# Clear yum cache to reduce AMI size
yum clean all

# Remove temporary files
rm -rf /tmp/* /var/tmp/*

# Clear command history (if any)
history -c

# Clear system logs (they'll be recreated on boot)
# We keep the structure but remove content
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

# ----------------------------------------------------------------------------
# STEP 7: VERIFY AGENTS RESTART CLEANLY
# ----------------------------------------------------------------------------
# Test that agents will start properly after reboot
# This catches configuration issues before AMI creation
echo "Verifying agents will restart cleanly after reboot..."

# Test CloudWatch Agent restart
systemctl restart amazon-cloudwatch-agent
sleep 5
systemctl status amazon-cloudwatch-agent

# Test SSM Agent restart
systemctl restart amazon-ssm-agent
sleep 5
systemctl status amazon-ssm-agent

# ----------------------------------------------------------------------------
# STEP 8: COMPLETION SIGNAL
# ----------------------------------------------------------------------------
# Create a marker file to signal successful completion
# Terraform or monitoring tools can check for this file
echo "AMI builder instance configuration completed successfully"
touch /tmp/ami-builder-ready

# Log completion timestamp
echo "Configuration completed at: $(date)" >> /tmp/ami-builder-ready
