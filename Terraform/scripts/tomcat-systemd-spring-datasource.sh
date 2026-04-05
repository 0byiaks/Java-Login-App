#!/bin/bash
# Run on Tomcat EC2 as root (sudo bash ...). Reads /etc/tomcat/spring-datasource-password
# and wires SPRING_DATASOURCE_PASSWORD the same way as modules/tomcat-asg/user_data.sh:
#   - /etc/tomcat/tomcat.conf (loaded by tomcat.service)
#   - /etc/sysconfig/tomcat-spring-datasource + systemd drop-in (backup)
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

PW_FILE=/etc/tomcat/spring-datasource-password
if [[ ! -s "$PW_FILE" ]]; then
  echo "Missing or empty $PW_FILE (fetch RDS secret first or run full Tomcat user-data)." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 1
fi

echo "Writing SPRING_DATASOURCE_PASSWORD into tomcat.conf + systemd env file..."
/usr/bin/python3 <<'PY'
import pathlib

def systemd_quoted(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`") + '"'

def strip_spring(lines):
    return [l for l in lines if not l.strip().startswith("SPRING_DATASOURCE_PASSWORD=")]

raw = pathlib.Path("/etc/tomcat/spring-datasource-password").read_text().rstrip("\n\r")
line = "SPRING_DATASOURCE_PASSWORD=" + systemd_quoted(raw)

tc = pathlib.Path("/etc/tomcat/tomcat.conf")
existing = tc.read_text(encoding="utf-8") if tc.exists() else ""
out_lines = strip_spring([l for l in existing.splitlines() if l.strip() != ""])
out_lines.append(line)
tc.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
tc.chmod(0o644)

path = pathlib.Path("/etc/sysconfig/tomcat-spring-datasource")
path.write_text(line + "\n", encoding="utf-8")
path.chmod(0o600)
PY
chown root:root /etc/sysconfig/tomcat-spring-datasource
chown root:root /etc/tomcat/tomcat.conf

install -d -m 755 /etc/systemd/system/tomcat.service.d
cat > /etc/systemd/system/tomcat.service.d/spring-datasource.conf <<'UNIT'
[Service]
EnvironmentFile=-/etc/sysconfig/tomcat-spring-datasource
UNIT

systemctl daemon-reload

if [[ "${1:-}" == "--no-restart" ]]; then
  echo "Skip restart (--no-restart). Run: sudo systemctl restart tomcat"
  exit 0
fi

echo "Restarting tomcat..."
systemctl restart tomcat

spring_ok=0
for j in $(seq 1 20); do
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    [[ -r "/proc/$pid/environ" ]] || continue
    if tr '\0' '\n' < "/proc/$pid/environ" | grep -q '^SPRING_DATASOURCE_PASSWORD='; then
      echo "OK: SPRING_DATASOURCE_PASSWORD in tomcat process PID=$pid (check $j)"
      spring_ok=1
      break
    fi
  done < <(pgrep -u tomcat 2>/dev/null || true)
  [[ "$spring_ok" -eq 1 ]] && break
  sleep 3
done

if [[ "$spring_ok" -ne 1 ]]; then
  echo "WARNING: could not confirm variable in process environ; check journalctl -u tomcat" >&2
  exit 1
fi
