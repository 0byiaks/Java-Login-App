#!/bin/bash
set -e
exec > >(tee /var/log/tomcat-golden-ami-build.log) 2>&1

# ----------------------------------------------------------------------------
# TOMCAT GOLDEN AMI CONFIGURATION SCRIPT
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# STEP 1: INSTALL JDK 11
# ----------------------------------------------------------------------------
echo "STEP1: Installing JDK 11 via amazon-linux-extras..."
amazon-linux-extras install -y java-openjdk11

JAVA_HOME=$(readlink -f /usr/bin/java | sed 's|/bin/java||')
export JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH
java -version
echo "STEP1: JDK 11 OK — JAVA_HOME=$JAVA_HOME"

# ----------------------------------------------------------------------------
# STEP 2: INSTALL APACHE TOMCAT
# ----------------------------------------------------------------------------
echo "STEP2: Installing Apache Tomcat via amazon-linux-extras..."
amazon-linux-extras install -y tomcat8.5

test -d /var/lib/tomcat/webapps || { echo "ERROR: /var/lib/tomcat/webapps missing after install"; rpm -qa | grep tomcat; exit 1; }
echo "STEP2: Tomcat OK — webapps at /var/lib/tomcat/webapps"

# ----------------------------------------------------------------------------
# STEP 3: SET JAVA_HOME FOR TOMCAT SERVICE
# The RPM-provided tomcat.service sources /etc/sysconfig/tomcat for env vars.
# We must set JAVA_HOME there so the service can find Java on boot.
# Do NOT create a custom /etc/systemd/system/tomcat.service — the RPM one
# already handles PID files, tmpfiles.d, and startup correctly.
# ----------------------------------------------------------------------------
echo "STEP3: Setting JAVA_HOME in /etc/sysconfig/tomcat..."
# Uncomment existing JAVA_HOME line if present, otherwise append
if grep -q "^#JAVA_HOME=" /etc/sysconfig/tomcat 2>/dev/null; then
  sed -i "s|^#JAVA_HOME=.*|JAVA_HOME=$JAVA_HOME|" /etc/sysconfig/tomcat
elif grep -q "^JAVA_HOME=" /etc/sysconfig/tomcat 2>/dev/null; then
  sed -i "s|^JAVA_HOME=.*|JAVA_HOME=$JAVA_HOME|" /etc/sysconfig/tomcat
else
  echo "JAVA_HOME=$JAVA_HOME" >> /etc/sysconfig/tomcat
fi
echo "STEP3: JAVA_HOME set to $JAVA_HOME"

# ----------------------------------------------------------------------------
# STEP 4: INSTALL MYSQL CLIENT
# ----------------------------------------------------------------------------
echo "STEP4: Installing MySQL client..."
yum install -y mysql
echo "STEP4: MySQL client OK"

# ----------------------------------------------------------------------------
# STEP 5: CLEAN UP STALE SYSTEMD OVERRIDE AND ENABLE TOMCAT
# Remove any /etc/systemd/system/tomcat.service that may have been baked from
# a prior AMI iteration — it overrides the RPM-provided service file and can
# reference paths that don't exist (e.g. /usr/share/tomcat/bin/startup.sh).
# The RPM-provided file at /usr/lib/systemd/system/tomcat.service is correct.
# ----------------------------------------------------------------------------
echo "STEP5: Removing stale systemd override (if any)..."
rm -f /etc/systemd/system/tomcat.service

echo "STEP5: Verifying Tomcat install layout..."
find /usr/share/tomcat /var/lib/tomcat /usr/libexec/tomcat 2>/dev/null | head -40 || true
echo "--- RPM service file ---"
cat /usr/lib/systemd/system/tomcat.service 2>/dev/null || echo "RPM service file not found at /usr/lib/systemd/system/tomcat.service"
echo "--- /etc/sysconfig/tomcat ---"
cat /etc/sysconfig/tomcat 2>/dev/null || echo "No /etc/sysconfig/tomcat"

echo "STEP5: Enabling Tomcat service..."
systemctl daemon-reload
systemctl enable tomcat
echo "STEP5: Tomcat enabled OK"

# ----------------------------------------------------------------------------
# STEP 6: START TOMCAT AND VERIFY
# ----------------------------------------------------------------------------
echo "STEP6: Starting Tomcat..."
systemctl start tomcat
sleep 10
systemctl status tomcat
echo "STEP6: Tomcat started OK"

# ----------------------------------------------------------------------------
# STEP 7: TEST HTTP RESPONSE
# ----------------------------------------------------------------------------
echo "STEP7: Testing Tomcat HTTP response..."
curl -f http://localhost:8080 || echo "Tomcat HTTP check: no default page (expected — no webapps deployed yet)"

# ----------------------------------------------------------------------------
# STEP 8: SIGNAL COMPLETION
# ----------------------------------------------------------------------------
echo "Tomcat Golden AMI configuration completed successfully"
touch /tmp/tomcat-golden-ami-ready
echo "Configuration completed at: $(date)" >> /tmp/tomcat-golden-ami-ready
