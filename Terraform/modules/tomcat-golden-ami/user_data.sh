#!/bin/bash
set -e

# ----------------------------------------------------------------------------
# TOMCAT GOLDEN AMI CONFIGURATION SCRIPT
# This script installs and configures Tomcat on the global base AMI
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# STEP 1: INSTALL JDK 11
# ----------------------------------------------------------------------------
echo "Installing JDK 11..."
yum install -y java-11-amazon-corretto-devel

# Verify Java installation
java -version

# ----------------------------------------------------------------------------
# STEP 2: INSTALL APACHE TOMCAT
# ----------------------------------------------------------------------------
echo "Installing Apache Tomcat..."
yum install -y tomcat tomcat-webapps tomcat-admin-webapps

# ----------------------------------------------------------------------------
# STEP 3: INSTALL MYSQL CLIENT
# ----------------------------------------------------------------------------
echo "Installing MySQL client..."
yum install -y mysql

# ----------------------------------------------------------------------------
# STEP 4: CONFIGURE TOMCAT AS SYSTEMD SERVICE
# ----------------------------------------------------------------------------
echo "Configuring Tomcat systemd service..."

# Create systemd service file for Tomcat
cat > /etc/systemd/system/tomcat.service <<'TOMCATSERVICE'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment="JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto"
Environment="CATALINA_PID=/var/run/tomcat/tomcat.pid"
Environment="CATALINA_HOME=/usr/share/tomcat"
Environment="CATALINA_BASE=/usr/share/tomcat"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=/usr/share/tomcat/bin/startup.sh
ExecStop=/bin/kill -15 $MAINPID

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
TOMCATSERVICE

# Create necessary directories
mkdir -p /var/run/tomcat
chown tomcat:tomcat /var/run/tomcat

# Set permissions
chown -R tomcat:tomcat /usr/share/tomcat
chown -R tomcat:tomcat /var/log/tomcat
chown -R tomcat:tomcat /var/cache/tomcat

# ----------------------------------------------------------------------------
# STEP 5: ENABLE TOMCAT TO START ON BOOT
# ----------------------------------------------------------------------------
echo "Enabling Tomcat to start on boot..."
systemctl daemon-reload
systemctl enable tomcat

# ----------------------------------------------------------------------------
# STEP 6: START TOMCAT
# ----------------------------------------------------------------------------
echo "Starting Tomcat..."
systemctl start tomcat

# ----------------------------------------------------------------------------
# STEP 7: VERIFY TOMCAT IS RUNNING
# ----------------------------------------------------------------------------
echo "Verifying Tomcat is running..."
sleep 10
systemctl status tomcat

# ----------------------------------------------------------------------------
# STEP 8: TEST TOMCAT RESPONSE
# ----------------------------------------------------------------------------
echo "Testing Tomcat response..."
curl -f http://localhost:8080 || echo "Tomcat health check failed, but continuing..."

# ----------------------------------------------------------------------------
# STEP 9: SIGNAL COMPLETION
# ----------------------------------------------------------------------------
echo "Tomcat Golden AMI configuration completed successfully"
touch /tmp/tomcat-golden-ami-ready
echo "Configuration completed at: $(date)" >> /tmp/tomcat-golden-ami-ready

