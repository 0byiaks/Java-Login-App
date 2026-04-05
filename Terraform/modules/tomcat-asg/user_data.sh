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
TOMCAT_BASE="$(dirname "$TOMCAT_WEBAPPS_DIR")"

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

if [ -z "$JFROG_USER" ] || [ -z "$JFROG_PASS" ]; then
  echo "ERROR: JFrog credentials missing from secret '$SECRET_ID' (expected keys: jfrogusername, jfrogpassword)"
  exit 1
fi
echo "JFrog user resolved: $JFROG_USER"

echo "Fetching RDS master password from Secrets Manager for Spring (SPRING_DATASOURCE_PASSWORD)..."
RDS_SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$RDS_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)
DB_PASSWORD=$(echo "$RDS_SECRET_JSON" | jq -r '.password // empty')
if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: RDS secret missing .password (ARN=$RDS_SECRET_ARN)"
  exit 1
fi
install -d -m 755 /etc/tomcat
umask 077
printf '%s' "$DB_PASSWORD" > /etc/tomcat/spring-datasource-password
umask 022
chmod 640 /etc/tomcat/spring-datasource-password
chown root:tomcat /etc/tomcat/spring-datasource-password
install -d -m 755 "$TOMCAT_BASE/bin"
cat > "$TOMCAT_BASE/bin/setenv.sh" <<'SETENV'
#!/bin/bash
# Installed by user-data: Spring Boot reads SPRING_DATASOURCE_PASSWORD from the environment.
if [ -r /etc/tomcat/spring-datasource-password ]; then
  export SPRING_DATASOURCE_PASSWORD="$(tr -d '\n\r' < /etc/tomcat/spring-datasource-password)"
fi
SETENV
chmod 750 "$TOMCAT_BASE/bin/setenv.sh"
chown root:tomcat "$TOMCAT_BASE/bin/setenv.sh"

echo "Downloading WAR from JFrog..."
curl -fLS \
  -u "$${JFROG_USER}:$${JFROG_PASS}" \
  -o /tmp/app.war \
  "$JFROG_WAR_URL" || {
  echo "ERROR: curl failed downloading $JFROG_WAR_URL (check credentials and URL above)"
  exit 1
}

test -s /tmp/app.war || {
  echo "ERROR: Downloaded WAR is empty — curl exited 0 but wrote nothing"
  exit 1
}
echo "WAR downloaded OK ($(du -sh /tmp/app.war | cut -f1))"

echo "Deploying WAR to Tomcat webapps as ROOT.war (serves at /)..."
rm -rf "$TOMCAT_WEBAPPS_DIR/ROOT" "$TOMCAT_WEBAPPS_DIR/ROOT.war"
cp /tmp/app.war "$TOMCAT_WEBAPPS_DIR/ROOT.war"
chown tomcat:tomcat "$TOMCAT_WEBAPPS_DIR/ROOT.war"
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
