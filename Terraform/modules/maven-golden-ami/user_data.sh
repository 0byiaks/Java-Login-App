#!/bin/bash
set -e

# ----------------------------------------------------------------------------
# MAVEN GOLDEN AMI CONFIGURATION SCRIPT
# This script installs and configures Maven on the global base AMI
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# STEP 1: INSTALL JDK 11
# ----------------------------------------------------------------------------
echo "Installing JDK 11..."
yum install -y java-11-amazon-corretto-devel

# Verify Java installation
java -version

# ----------------------------------------------------------------------------
# STEP 2: INSTALL GIT
# ----------------------------------------------------------------------------
echo "Installing Git..."
yum install -y git

# Verify Git installation
git --version

# ----------------------------------------------------------------------------
# STEP 3: INSTALL APACHE MAVEN
# ----------------------------------------------------------------------------
echo "Installing Apache Maven..."
yum install -y maven

# Confirm Maven installation
mvn -version

# ----------------------------------------------------------------------------
# STEP 4: CONFIGURE MAVEN_HOME AND PATH
# ----------------------------------------------------------------------------
echo "Configuring MAVEN_HOME and PATH..."

# Create /etc/profile.d/maven.sh for all users
cat > /etc/profile.d/maven.sh <<'MAVENPROFILE'
export MAVEN_HOME=/usr/share/maven
export PATH=$PATH:$MAVEN_HOME/bin
MAVENPROFILE

# Make the script executable
chmod +x /etc/profile.d/maven.sh

# ----------------------------------------------------------------------------
# STEP 5: SIGNAL COMPLETION
# ----------------------------------------------------------------------------
echo "Maven Golden AMI configuration completed successfully"
touch /tmp/maven-golden-ami-ready
echo "Configuration completed at: $(date)" >> /tmp/maven-golden-ami-ready
