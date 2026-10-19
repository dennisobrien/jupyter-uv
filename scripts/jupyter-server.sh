#!/usr/bin/env bash
# Start/stop/status the local JupyterLab server used for MCP-driven notebook control.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

RUN_DIR=".run"
LOG_FILE="${RUN_DIR}/jupyter.log"
ENV_FILE=".env"

# Load .env before reading settings so it can override the defaults below.
# Variables already exported in the environment take precedence over .env.
if [ -f "${ENV_FILE}" ]; then
  saved_env="$(export -p)"
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
  eval "${saved_env}"
  unset saved_env
fi

PORT="${JUPYTER_PORT:-8888}"
IP="${JUPYTER_IP:-127.0.0.1}"
# Default to the directory containing this repo, so sibling projects are browsable.
NOTEBOOK_DIR="${JUPYTER_NOTEBOOK_DIR:-$(cd .. && pwd)}"
STARTUP_TIMEOUT="${JUPYTER_STARTUP_TIMEOUT:-60}"

if [ "${IP}" = "0.0.0.0" ]; then
  CHECK_HOST="127.0.0.1"
else
  CHECK_HOST="${IP}"
fi

mkdir -p "${RUN_DIR}"

# True if a Jupyter server accepting our token is answering on ${PORT}. Asking
# the server itself avoids trusting pid files that may be stale or reused.
is_running() {
  [ -n "${JUPYTER_TOKEN:-}" ] &&
    curl -sf -o /dev/null --max-time 2 \
      -H "Authorization: token ${JUPYTER_TOKEN}" \
      "http://${CHECK_HOST}:${PORT}/api/status"
}

# Print the pid of the Jupyter server on ${PORT} (from Jupyter's runtime files).
server_pid() {
  uv run --quiet python -c '
import sys
from jupyter_server.serverapp import list_running_servers
port = int(sys.argv[1])
for s in list_running_servers():
    if s.get("port") == port:
        print(s["pid"])
        break
' "${PORT}"
}

start() {
  if [ -z "${JUPYTER_TOKEN:-}" ]; then
    echo "JUPYTER_TOKEN not set. Add it to ${ENV_FILE} (see .env.example)." >&2
    return 1
  fi

  if is_running; then
    echo "JupyterLab already running (pid $(server_pid)) on http://localhost:${PORT}"
    return 0
  fi

  if [ -f "${LOG_FILE}" ]; then
    mv -f "${LOG_FILE}" "${LOG_FILE}.1"
  fi

  # JUPYTER_TOKEN is read from the environment (exported from .env above), which
  # keeps it out of the process command line. port_retries=0 makes a busy port
  # fail loudly instead of silently moving to another port.
  nohup uv run jupyter lab \
    --no-browser \
    --port="${PORT}" \
    --ServerApp.port_retries=0 \
    --ip="${IP}" \
    --notebook-dir="${NOTEBOOK_DIR}" \
    --SQLiteYStore.db_path="${RUN_DIR}/jupyter_ystore.db" \
    --SQLiteYStore.squash_after_inactivity_of=86400 \
    "$@" \
    >"${LOG_FILE}" 2>&1 &
  local launcher=$!
  disown

  echo "Starting JupyterLab on http://localhost:${PORT} (logs: ${LOG_FILE})"
  for _ in $(seq 1 "${STARTUP_TIMEOUT}"); do
    if is_running; then
      echo "JupyterLab is up (pid $(server_pid))."
      return 0
    fi
    if ! kill -0 "${launcher}" 2>/dev/null; then
      echo "JupyterLab exited during startup. Last log lines:" >&2
      tail -n 20 "${LOG_FILE}" >&2
      return 1
    fi
    sleep 1
  done
  echo "JupyterLab did not respond within ${STARTUP_TIMEOUT}s; check ${LOG_FILE}." >&2
  return 1
}

stop() {
  if ! is_running; then
    echo "JupyterLab is not running on port ${PORT}."
    return 0
  fi
  # Requests a clean shutdown (including kernels) via the server API, escalating
  # to SIGTERM/SIGKILL only if the server does not exit.
  uv run --quiet jupyter server stop "${PORT}"
  echo "Stopped JupyterLab on port ${PORT}."
}

status() {
  if is_running; then
    echo "JupyterLab running (pid $(server_pid)) on http://localhost:${PORT}"
  else
    echo "JupyterLab is not running on port ${PORT}."
    return 1
  fi
}

cmd="${1:-}"
if [ $# -gt 0 ]; then
  shift
fi
case "${cmd}" in
  start) start "$@" ;;
  stop) stop ;;
  restart) stop && start "$@" ;;
  status) status ;;
  *)
    echo "Usage: $0 {start|stop|restart|status} [extra 'jupyter lab' args for start/restart]" >&2
    exit 1
    ;;
esac
