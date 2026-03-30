#!/bin/bash
set -e
exec > >(tee /var/log/tomcat-userdata.log) 2>&1

AWS_REGION="${aws_region}"
SECRET_ID="${secret_id}"
JFROG_WAR_URL="${jfrog_war_url}"
TOMCAT_WEBAPPS_DIR="/usr/share/tomcat/webapps"

echo "Installing aws-cli, jq, curl..."
yum install -y aws-cli jq curl

echo "Fetching JFrog credentials from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

JFROG_USER=$(echo "$SECRET_JSON" | jq -r '.jfrogusername // empty')
JFROG_PASS=$(echo "$SECRET_JSON" | jq -r '.jfrogpassword // empty')

echo "Downloading WAR from JFrog..."
curl -sf -u "$${JFROG_USER}:$${JFROG_PASS}" -o /tmp/app.war "$JFROG_WAR_URL" || {
  echo "ERROR: Failed to download WAR from JFrog"
  exit 1
}

echo "Deploying WAR to Tomcat webapps as app.war..."
cp /tmp/app.war "$TOMCAT_WEBAPPS_DIR/app.war"
chown tomcat:tomcat "$TOMCAT_WEBAPPS_DIR/app.war"
rm -f /tmp/app.war

echo "Restarting Tomcat..."
systemctl restart tomcat

echo "Waiting for HTTP on port 8080 (up to ~2 minutes)..."
ok=0
for i in $(seq 1 60); do
  if curl -s -o /dev/null --connect-timeout 2 http://127.0.0.1:8080/; then
    echo "Tomcat is responding on port 8080 (attempt $i)"
    ok=1
    break
  fi
  echo "  ... waiting ($i/60)"
  sleep 2
done

if [ "$ok" -ne 1 ]; then
  echo "ERROR: Timed out waiting for port 8080"
  systemctl status tomcat || true
  exit 1
fi

systemctl is-active --quiet tomcat || {
  echo "ERROR: Tomcat service is not active"
  exit 1
}

echo "SUCCESS: WAR deployed from JFrog, Tomcat running and port 8080 responding."
