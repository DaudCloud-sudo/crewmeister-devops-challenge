#!/usr/bin/env bash
set -Eeuo pipefail

context="kind-devops-lab"
password_file="${HOME}/.config/crewmeister/mysql-exporter-password"
sql_file=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$sql_file" ]]; then
    rm -f -- "$sql_file"
  fi
}
trap cleanup EXIT

[[ "${CONFIRM_MYSQL_EXPORTER_ACCOUNT:-}" == "CREATE" ]] \
  || fail "Review the exporter account grants, then rerun with CONFIRM_MYSQL_EXPORTER_ACCOUNT=CREATE."

for command_name in kubectl openssl python3 tr; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

kubectl --context "$context" -n default rollout status deployment/mysql --timeout=90s \
  || fail "MySQL Deployment is not ready; no account changes were made."

account_count="$(kubectl --context "$context" -n default exec deployment/mysql -- sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql --batch --skip-column-names --user=root --database=mysql --execute="SELECT COUNT(*) FROM user WHERE user = '\''prometheus_exporter'\'' AND host = '\''%'\''"')" \
  || fail "Could not check for an existing exporter account."
[[ "$account_count" == "0" ]] \
  || fail "The exporter account already exists; inspect it and reconcile its credential manually. No account or Secret changes were made."

secret_name="$(kubectl --context "$context" -n monitoring get secret mysql-exporter-auth --ignore-not-found -o name)" \
  || fail "Could not check the monitoring Secret."
[[ -z "$secret_name" ]] \
  || fail "Secret mysql-exporter-auth already exists; inspect it before changing credentials. No account or Secret changes were made."

[[ ! -e "$password_file" && ! -L "$password_file" ]] \
  || fail "Local password file already exists at $password_file; preserve it and reconcile manually."
umask 077
install -d -m 700 "$(dirname -- "$password_file")"
openssl rand -hex 32 | tr -d '\n' >"$password_file"
chmod 600 "$password_file"

sql_file="$(mktemp)"
chmod 600 "$sql_file"
python3 - "$password_file" "$sql_file" <<'PY'
from pathlib import Path
import re
import sys

password = Path(sys.argv[1]).read_text().strip()
if not re.fullmatch(r"[0-9a-f]{64}", password):
    raise SystemExit("Password file must contain exactly 64 lowercase hex characters.")

sql = (
    "CREATE USER 'prometheus_exporter'@'%' "
    f"IDENTIFIED BY '{password}' WITH MAX_USER_CONNECTIONS 3;\n"
    "GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* "
    "TO 'prometheus_exporter'@'%';\n"
)
Path(sys.argv[2]).write_text(sql)
PY

# The generated password is sent only through stdin to the MySQL client and is
# never included in command arguments or stdout.
kubectl --context "$context" -n default exec -i deployment/mysql -- sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql --user=root --database=mysql' <"$sql_file" \
  || fail "MySQL account creation failed. The local password file remains for diagnosis; inspect account state before retrying."

kubectl --context "$context" create secret generic mysql-exporter-auth \
  --namespace monitoring \
  --from-file=password="$password_file" \
  --dry-run=client -o yaml \
  | kubectl --context "$context" apply -f - \
  || fail "Kubernetes Secret creation failed. Keep the local password file safe; do not print it."

echo "PASS: MySQL exporter account and monitoring Secret were created. Password remains at $password_file and was not printed."
