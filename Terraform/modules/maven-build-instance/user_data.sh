#!/bin/bash
set -eo pipefail
exec > >(tee /var/log/maven-build-userdata.log) 2>&1

# Surface failing line/command in /var/log/maven-build-userdata.log (and cloud-init output).
trap 'ec=$?; echo "[user_data] Bash failed: exit=$${ec} file=$${BASH_SOURCE[0]:-user_data} line=$${BASH_LINENO[0]:-$LINENO} cmd=$${BASH_COMMAND}" >&2' ERR

AWS_REGION="${aws_region}"
SECRET_ID="${secret_id}"
# Public repo — clone without token
GIT_REPO="${git_repo_url}"
# Clone target directory name
CLONE_DIR="/home/ec2-user/Java-Login-App"
# Project root with pom.xml (nested module: repo/Java-Login-App/) — set from Terraform template (must match clone layout)
APP_DIR="${app_dir}"

echo "Installing dependencies (git, aws-cli, python3)..."
yum install -y git aws-cli python3

echo "Fetching JFrog credentials from Secrets Manager (jfrogusername, jfrogpassword)..."
AWS_SM_ERR=$(mktemp)
trap 'rm -f "$AWS_SM_ERR"' EXIT
if ! SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text 2>"$AWS_SM_ERR"); then
  echo "ERROR: aws secretsmanager get-secret-value failed (secret_id=$SECRET_ID region=$AWS_REGION)."
  echo "ERROR: stderr from AWS CLI:"
  cat "$AWS_SM_ERR"
  exit 1
fi
rm -f "$AWS_SM_ERR"
trap - EXIT
echo "Secrets Manager SecretString length: $${#SECRET_JSON} bytes (non-secret diagnostic only)."
if [ -z "$${SECRET_JSON}" ]; then
  echo "ERROR: SecretString is empty. Check the secret exists and IAM allows secretsmanager:GetSecretValue."
  exit 1
fi

rm -rf "$CLONE_DIR"
mkdir -p /home/ec2-user/.m2
chown ec2-user:ec2-user /home/ec2-user/.m2
cd /home/ec2-user
echo "Cloning public repository: $GIT_REPO"
git clone "$GIT_REPO" Java-Login-App
chown -R ec2-user:ec2-user "$CLONE_DIR"

echo "Writing Maven settings.xml for JFrog..."
# Root runs Python (export SECRET_JSON): avoids sudo env limits and surfaces stderr clearly in the log.
export SECRET_JSON
/usr/bin/python3 <<'PY'
import json
import os
import sys
import traceback

def esc(s):
    if s is None:
        return ""
    s = str(s)
    return (s.replace("&", "&amp;")
             .replace("<", "&lt;")
             .replace(">", "&gt;")
             .replace('"', "&quot;")
             .replace("'", "&apos;"))

def main():
    raw = os.environ.get("SECRET_JSON", "")
    if not raw.strip():
        print("ERROR: SECRET_JSON is empty in the environment after export.", file=sys.stderr)
        sys.exit(1)
    try:
        j = json.loads(raw)
    except json.JSONDecodeError as e:
        print(
            "ERROR: SecretString is not valid JSON: %s (line %s, column %s, position %s)."
            % (e.msg, e.lineno, e.colno, e.pos),
            file=sys.stderr,
        )
        print(
            "ERROR: Expected a JSON object with keys jfrogusername and jfrogpassword.",
            file=sys.stderr,
        )
        sys.exit(1)

    if not isinstance(j, dict):
        print("ERROR: JSON root must be an object, got %s." % type(j).__name__, file=sys.stderr)
        sys.exit(1)

    keys = set(j.keys())
    need = {"jfrogusername", "jfrogpassword"}
    missing = need - keys
    if missing:
        print(
            "ERROR: Missing keys %s. Present keys: %s. Fix the secret or align key names in user_data.sh."
            % (sorted(missing), sorted(keys)),
            file=sys.stderr,
        )
        sys.exit(1)

    u = esc(j.get("jfrogusername", ""))
    p = esc(j.get("jfrogpassword", ""))
    if not u or not p:
        print(
            "ERROR: jfrogusername or jfrogpassword is empty after parsing JSON.",
            file=sys.stderr,
        )
        sys.exit(1)

    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">
  <servers>
    <server><id>central</id><username>{u}</username><password>{p}</password></server>
    <server><id>snapshots</id><username>{u}</username><password>{p}</password></server>
  </servers>
</settings>
'''
    path = "/home/ec2-user/.m2/settings.xml"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(xml)
    os.chmod(path, 0o600)

if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        print("ERROR: Unexpected Python failure while writing settings.xml:", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
PY

chown ec2-user:ec2-user /home/ec2-user/.m2/settings.xml
unset SECRET_JSON

# Golden AMI sets PATH/JAVA_HOME via /etc/profile.d; bash -lc for ec2-user skips that, and Corretto may not use /usr/bin/java.
load_jdk_maven_env() {
  local f d
  # With set -e, a profile.d script that returns non-zero would abort user_data; ignore source failures.
  for f in /etc/profile.d/*.sh; do
    [ -r "$f" ] && . "$f" || true
  done
  if ! command -v java >/dev/null 2>&1 && [ -L /etc/alternatives/java ]; then
    export PATH="$(dirname "$(readlink -f /etc/alternatives/java)"):$PATH"
  fi
  if ! command -v java >/dev/null 2>&1; then
    for d in /usr/lib/jvm/*/bin; do
      # Use if/fi, not [ ] && ... — with set -e + ERR trap, a failed [ -x ] in && can abort user_data.
      if [ -x "$d/java" ]; then
        export PATH="$d:$PATH"
        break
      fi
    done
  fi
}
load_jdk_maven_env
if ! command -v java >/dev/null 2>&1 || ! command -v mvn >/dev/null 2>&1; then
  echo "JDK/Maven not on PATH; installing (matches modules/maven-golden-ami/user_data.sh)..."
  if ! yum install -y java-11-amazon-corretto-devel maven; then
    echo "ERROR: yum install java-11-amazon-corretto-devel maven failed."
    exit 1
  fi
  load_jdk_maven_env
fi
if ! command -v java >/dev/null 2>&1 || ! command -v mvn >/dev/null 2>&1; then
  echo "ERROR: java or mvn still not on PATH after yum install."
  exit 1
fi

# Explicit check so logs show a clear pass/fail before Maven runs.
verify_java_installed() {
  local jb
  jb=$(command -v java 2>/dev/null || true)
  if [ -z "$jb" ]; then
    echo "ERROR: Java verification failed: no java on PATH."
    return 1
  fi
  if [ ! -x "$jb" ]; then
    echo "ERROR: Java verification failed: not executable: $jb"
    return 1
  fi
  echo "OK: Java is installed — binary: $jb"
  if ! java -version 2>&1; then
    echo "ERROR: Java verification failed: java -version returned non-zero."
    return 1
  fi
  echo "OK: java -version succeeded."
}
verify_java_installed || exit 1

echo "Validating Java and Maven (java -version, mvn -v)..."
# Use /bin/bash: env looks up "bash" on PATH; PATH=... may omit /bin and /usr/bin.
sudo -u ec2-user env PATH="$PATH" $${JAVA_HOME:+JAVA_HOME="$JAVA_HOME"} /bin/bash -c "cd ${app_dir} && java -version && mvn -v"

echo "Running mvn clean deploy (packages WAR + deploys to JFrog per pom distributionManagement)..."
sudo -u ec2-user env PATH="$PATH" $${JAVA_HOME:+JAVA_HOME="$JAVA_HOME"} /bin/bash -c "cd ${app_dir} && mvn clean deploy -s /home/ec2-user/.m2/settings.xml"

# WAR path matches Java-Login-App/pom.xml (artifactId dptweb, version 1.0)
echo "Validating WAR artifact (target/dptweb-1.0.war)..."
sudo -u ec2-user /bin/bash -lc "cd ${app_dir} && test -f target/dptweb-1.0.war && test -s target/dptweb-1.0.war && ls -la target/dptweb-1.0.war" || {
  echo "ERROR: WAR missing or empty under target/ (expected dptweb-1.0.war from pom)"
  exit 1
}

echo "Maven package, JFrog deploy, and WAR validation finished successfully."
