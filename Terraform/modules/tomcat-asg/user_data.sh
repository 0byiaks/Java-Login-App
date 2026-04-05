#!/bin/bash
set -e
exec > >(tee /var/log/tomcat-userdata.log) 2>&1

AWS_REGION="${aws_region}"
SECRET_ID="${secret_id}"
JFROG_WAR_URL="${jfrog_war_url}"
RDS_SECRET_ARN="${rds_secret_arn}"

TOMCAT_WEBAPPS_DIR=$(find /usr/share/tomcat /var/lib/tomcat /opt/tomcat -maxdepth 2 -name "webapps" -type d 2>/dev/null | head -1)
if [ -z "$TOMCAT_WEBAPPS_DIR" ]; then
  echo "ERROR: Could not locate Tomcat webapps directory. Tomcat may not be installed."
  exit 1
fi
echo "Found Tomcat webapps directory: $TOMCAT_WEBAPPS_DIR"

echo "Installing aws-cli, jq, curl..."
yum install -y aws-cli jq curl

# ----------------------------------------------------------------------------
# STEP 1: Fetch JFrog credentials
# ----------------------------------------------------------------------------
echo "Fetching JFrog credentials from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

JFROG_USER=$(echo "$SECRET_JSON" | jq -r '.jfrogusername // empty')
JFROG_PASS=$(echo "$SECRET_JSON" | jq -r '.jfrogpassword // empty')

if [ -z "$JFROG_USER" ] || [ -z "$JFROG_PASS" ]; then
  echo "ERROR: JFrog credentials missing from secret '$SECRET_ID'"
  exit 1
fi
echo "JFrog user resolved: $JFROG_USER"

# ----------------------------------------------------------------------------
# STEP 2: Fetch RDS password and inject into tomcat.conf
# ----------------------------------------------------------------------------
echo "Fetching RDS password from Secrets Manager..."
RDS_SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$RDS_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)
DB_PASSWORD=$(echo "$RDS_SECRET_JSON" | jq -r '.password // empty')

if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: RDS secret missing .password key (ARN=$RDS_SECRET_ARN)"
  exit 1
fi
echo "RDS password fetched OK"

# Inject into /etc/tomcat/tomcat.conf (systemd EnvironmentFile loaded by tomcat.service).
# Use unquoted value — systemd reads # in the middle of an unquoted value as literal,
# not as a comment (only lines *starting* with # are comments in systemd EnvironmentFile).
# printf %s prevents any shell re-interpretation of the password value.
echo "Injecting SPRING_DATASOURCE_PASSWORD into /etc/tomcat/tomcat.conf..."
sed -i '/^SPRING_DATASOURCE_PASSWORD=/d' /etc/tomcat/tomcat.conf
printf 'SPRING_DATASOURCE_PASSWORD=%s\n' "$DB_PASSWORD" >> /etc/tomcat/tomcat.conf
chmod 644 /etc/tomcat/tomcat.conf
echo "Injection done. tomcat.conf tail:"
tail -3 /etc/tomcat/tomcat.conf

systemctl daemon-reload

# ----------------------------------------------------------------------------
# STEP 3: Download and deploy WAR
# ----------------------------------------------------------------------------
echo "Downloading WAR from JFrog..."
curl -fLS \
  -u "$${JFROG_USER}:$${JFROG_PASS}" \
  -o /tmp/app.war \
  "$JFROG_WAR_URL" || {
  echo "ERROR: curl failed downloading $JFROG_WAR_URL"
  exit 1
}

test -s /tmp/app.war || {
  echo "ERROR: Downloaded WAR is empty"
  exit 1
}
echo "WAR downloaded OK ($(du -sh /tmp/app.war | cut -f1))"

echo "Deploying WAR as ROOT.war (context path /)..."
rm -rf "$TOMCAT_WEBAPPS_DIR/ROOT" "$TOMCAT_WEBAPPS_DIR/ROOT.war"
cp /tmp/app.war "$TOMCAT_WEBAPPS_DIR/ROOT.war"
chown tomcat:tomcat "$TOMCAT_WEBAPPS_DIR/ROOT.war"
rm -f /tmp/app.war

# ----------------------------------------------------------------------------
# STEP 4: Start Tomcat and verify
# ----------------------------------------------------------------------------
echo "Restarting Tomcat..."
systemctl restart tomcat

echo "Verifying SPRING_DATASOURCE_PASSWORD is in tomcat process environment..."
spring_ok=0
for j in $(seq 1 20); do
  pid=$(pgrep -u tomcat 2>/dev/null | head -1 || true)
  if [ -n "$pid" ] && [ -r "/proc/$pid/environ" ]; then
    if tr '\0' '\n' < "/proc/$pid/environ" | grep -q '^SPRING_DATASOURCE_PASSWORD='; then
      echo "OK: SPRING_DATASOURCE_PASSWORD present in tomcat PID=$pid (attempt $j)"
      spring_ok=1
      break
    fi
  fi
  echo "  ... waiting for tomcat process ($j/20)"
  sleep 3
done

if [ "$spring_ok" -ne 1 ]; then
  echo "ERROR: SPRING_DATASOURCE_PASSWORD not in tomcat process after restart"
  echo "--- /etc/tomcat/tomcat.conf tail ---"
  tail -5 /etc/tomcat/tomcat.conf
  systemctl status tomcat || true
  exit 1
fi

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

echo "SUCCESS: WAR deployed, SPRING_DATASOURCE_PASSWORD injected, Tomcat responding on 8080."
