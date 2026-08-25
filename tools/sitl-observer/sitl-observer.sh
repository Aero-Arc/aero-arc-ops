#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OPS_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
PARENT_DIR=$(cd -- "$OPS_DIR/.." && pwd)
RUN_DIR=${AERO_ARC_SITL_RUN_DIR:-/tmp/aero-arc-sitl-observer}
BUILD_CACHE_DIR=${AERO_ARC_SITL_BUILD_CACHE_DIR:-/tmp/aero-arc-sitl-build-cache}
API_SOURCE=${AERO_ARC_API_SOURCE:-$PARENT_DIR/aero-arc-api}
RELAY_SOURCE=${AERO_ARC_RELAY_SOURCE:-$PARENT_DIR/aero-arc-relay}
CONFORMANCE_SOURCE=${AERO_ARC_CONFORMANCE_SOURCE:-$PARENT_DIR/aero-arc-conformance}
REGISTRY_SOURCE=${AERO_ARC_REGISTRY_SOURCE:-$PARENT_DIR/aero-arc-registry}
AGENT_SOURCE=${AERO_ARC_AGENT_SOURCE:-$PARENT_DIR/aero-arc-agent}
ARDUPILOT_SOURCE=${ARDUPILOT_SOURCE:-$PARENT_DIR/ardupilot}
SIM_VEHICLE=${SIM_VEHICLE:-$ARDUPILOT_SOURCE/Tools/autotest/sim_vehicle.py}
API_URL=${AERO_ARC_SITL_API_URL:-http://127.0.0.1:8080}
OPS_URL=${AERO_ARC_SITL_OPS_URL:-http://127.0.0.1:7357}
AGENT_ID=${AERO_ARC_SITL_AGENT_ID:-7bddaca99083eb313cf715a7d02db998869892d466d2000407311a6cbf5f4725}
AGENT_TOKEN=${AERO_ARC_SITL_AGENT_TOKEN:-sitl-agent-local-secret}
AIRCRAFT_ID=${AERO_ARC_SITL_AIRCRAFT_ID:-aircraft-sitl-1}
OPERATOR_ID=${AERO_ARC_SITL_OPERATOR_ID:-operator-local}
INTENT_ID=${AERO_ARC_SITL_INTENT_ID:-33333333-3333-4333-8333-333333333333}
FLIGHT_ID=${AERO_ARC_SITL_FLIGHT_ID:-flight-sitl-1}
VOLUME_ID=${AERO_ARC_SITL_VOLUME_ID:-volume-sitl-1}
ASSIGNMENT_ID=${AERO_ARC_SITL_ASSIGNMENT_ID:-$INTENT_ID}
TMUX_SESSION=${AERO_ARC_SITL_TMUX_SESSION:-aeroarc-sitl}
PLAN_MINUTES=${AERO_ARC_SITL_PLAN_MINUTES:-10}
MONITOR_HOURS=${AERO_ARC_SITL_MONITOR_HOURS:-24}

require_safe_run_dir() {
  case "$RUN_DIR" in
    /tmp/aero-arc-sitl-*) ;;
    *) echo "AERO_ARC_SITL_RUN_DIR must match /tmp/aero-arc-sitl-*" >&2; exit 2 ;;
  esac
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || { echo "required command not found: $1" >&2; exit 1; }
}

wait_http() {
  local name=$1 url=$2
  for _ in $(seq 1 90); do
    if curl --fail --silent --show-error "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "$name did not become ready at $url" >&2
  return 1
}

wait_port() {
  local name=$1 port=$2
  for _ in $(seq 1 90); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      exec 3>&-
      return 0
    fi
    sleep 1
  done
  echo "$name did not listen on port $port" >&2
  return 1
}

start_process() {
  local name=$1
  shift
  setsid "$@" >"$RUN_DIR/logs/$name.log" 2>&1 &
  echo "$!" >"$RUN_DIR/pids/$name.pid"
}

stop_processes() {
  if [[ ! -d "$RUN_DIR/pids" ]]; then
    return
  fi
  local file pid
  for file in "$RUN_DIR"/pids/*.pid; do
    [[ -f "$file" ]] || continue
    pid=$(<"$file")
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    fi
  done
  for _ in $(seq 1 20); do
    local alive=0
    for file in "$RUN_DIR"/pids/*.pid; do
      [[ -f "$file" ]] || continue
      pid=$(<"$file")
      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        alive=1
      fi
    done
    [[ "$alive" == 0 ]] && break
    sleep 0.25
  done
  for file in "$RUN_DIR"/pids/*.pid; do
    [[ -f "$file" ]] || continue
    pid=$(<"$file")
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
    fi
  done
}

require_free_port() {
  local port=$1
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
    exec 3>&-
    echo "port $port is already in use; stop the existing service before sitl-up" >&2
    return 1
  fi
}

generate_tls() {
  local tls_dir=$RUN_DIR/tls
  mkdir -p "$tls_dir"
  openssl req -x509 -newkey rsa:2048 -nodes -days 3 -subj "/CN=Aero Arc SITL CA" -keyout "$tls_dir/ca.key" -out "$tls_dir/ca.crt" >/dev/null 2>&1
  openssl req -newkey rsa:2048 -nodes -subj "/CN=localhost" -keyout "$tls_dir/relay.key" -out "$tls_dir/relay.csr" >/dev/null 2>&1
  printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n' >"$tls_dir/server.ext"
  openssl x509 -req -days 3 -in "$tls_dir/relay.csr" -CA "$tls_dir/ca.crt" -CAkey "$tls_dir/ca.key" -CAcreateserial -extfile "$tls_dir/server.ext" -out "$tls_dir/relay.crt" >/dev/null 2>&1
  openssl req -newkey rsa:2048 -nodes -subj "/CN=sitl-bootstrap" -keyout "$tls_dir/bootstrap.key" -out "$tls_dir/bootstrap.csr" >/dev/null 2>&1
  printf 'subjectAltName=URI:spiffe://aero-arc/bootstrap\nextendedKeyUsage=clientAuth\n' >"$tls_dir/client.ext"
  openssl x509 -req -days 3 -in "$tls_dir/bootstrap.csr" -CA "$tls_dir/ca.crt" -CAkey "$tls_dir/ca.key" -CAcreateserial -extfile "$tls_dir/client.ext" -out "$tls_dir/bootstrap.crt" >/dev/null 2>&1
  cp "$tls_dir/relay.crt" "$tls_dir/conformance.crt"
  cp "$tls_dir/relay.key" "$tls_dir/conformance.key"
}

generate_configs() {
  mkdir -p "$RUN_DIR/config"
  cat >"$RUN_DIR/config/relay.yaml" <<EOF
registry:
  enabled: true
  address: "127.0.0.1:50051"
  relay_id: "relay-local-1"
  advertise_address: "localhost"
  heartbeat_interval: "5s"
  request_timeout: "3s"
  tls:
    enabled: false
    ca_file: ""
    server_name: ""
agent_auth:
  tokens:
    "$AGENT_ID": "$AGENT_TOKEN"
control_auth:
  enabled: true
  client_ca_file: "$RUN_DIR/tls/ca.crt"
  allowed_identities:
    - "spiffe://aero-arc/bootstrap"
telemetry:
  enabled: true
  backend: "influxdb3"
  relay_id: "relay-local-1"
  queue_capacity: 10000
  workers: 2
  batch_size: 100
  flush_interval: "250ms"
  enqueue_timeout: "100ms"
  write_timeout: "5s"
  max_retries: 3
  retry_backoff: "200ms"
  influxdb:
    host: "http://127.0.0.1:18181"
    token: "local-development-no-auth"
    database: "aero_arc"
  agent_mappings:
    "$AGENT_ID":
      operator_id: "$OPERATOR_ID"
      aircraft_id: "$AIRCRAFT_ID"
sinks: {}
logging:
  level: "info"
  format: "text"
  output: "stdout"
EOF
  cat >"$RUN_DIR/config/conformance.yaml" <<EOF
service:
  management_address: "127.0.0.1:2113"
  grpc_address: "127.0.0.1:50052"
  grpc_tls:
    certificate_file: "$RUN_DIR/tls/conformance.crt"
    private_key_file: "$RUN_DIR/tls/conformance.key"
    client_ca_file: "$RUN_DIR/tls/ca.crt"
  shutdown_timeout: 15s
postgres:
  url: "postgres://conformance:conformance@127.0.0.1:55433/conformance?sslmode=disable"
influx:
  host: "http://127.0.0.1:18181"
  token: "local-development-no-auth"
  database: "aero_arc"
  poll_interval: 1s
  overlap_window: 30s
  settle_delay: 2s
  aircraft_batch_size: 100
  max_rows: 10000
registry:
  address: "127.0.0.1:50051"
  insecure: true
  publish_interval: 1s
  request_timeout: 3s
  lease_duration: 10s
  retry_delay: 1s
  batch_size: 20
worker:
  id: "conformance-sitl-1"
  lease_duration: 30s
  renew_interval: 10s
  claim_batch_size: 20
policy:
  version: "standard-v1"
  horizontal_tolerance_m: 5
  vertical_tolerance_m: 3
  open_after_samples: 3
  recover_after_samples: 3
  telemetry_freshness: 15s
logging:
  level: info
  format: text
EOF
}

build_binaries() {
  local cache=$BUILD_CACHE_DIR/go
  local ccache=$BUILD_CACHE_DIR/ccache
  mkdir -p "$RUN_DIR/bin" "$cache" "$ccache"
  (cd "$REGISTRY_SOURCE" && GOCACHE="$cache" CCACHE_DIR="$ccache" go build -buildvcs=false -o "$RUN_DIR/bin/registry" ./cmd/aero-arc-registry)
  (cd "$RELAY_SOURCE" && GOCACHE="$cache" CCACHE_DIR="$ccache" go build -buildvcs=false -o "$RUN_DIR/bin/relay" ./cmd/aero-arc-relay)
  (cd "$CONFORMANCE_SOURCE" && GOCACHE="$cache" CCACHE_DIR="$ccache" go build -buildvcs=false -o "$RUN_DIR/bin/conformance" ./cmd/aero-arc-conformance)
  (cd "$API_SOURCE" && GOCACHE="$cache" CCACHE_DIR="$ccache" go build -buildvcs=false -o "$RUN_DIR/bin/api" ./cmd/aero-arc-api)
  (cd "$AGENT_SOURCE" && GOCACHE="$cache" CCACHE_DIR="$ccache" go build -buildvcs=false -o "$RUN_DIR/bin/agent" ./cmd/aero-arc-agent)
  (cd "$SCRIPT_DIR/control" && GOCACHE="$cache" CCACHE_DIR="$ccache" go build -buildvcs=false -o "$RUN_DIR/bin/control" .)
}

api_post() {
  local path=$1 body=${2:-{}}
  local response_file=$RUN_DIR/last-api-response.json
  local status
  echo "POST $path" >&2
  status=$(curl --silent --show-error --output "$response_file" --write-out '%{http_code}' -H 'Content-Type: application/json' -X POST "$API_URL$path" --data "$body")
  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "API returned HTTP $status for POST $path:" >&2
    sed 's/^/  /' "$response_file" >&2
    echo >&2
    return 1
  fi
  sed -n '1,$p' "$response_file"
}

activate() {
  wait_http API "$API_URL/readyz"
  local now start end monitor
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  start=$(date -u -d '30 seconds ago' +%Y-%m-%dT%H:%M:%SZ)
  end=$(date -u -d "$PLAN_MINUTES minutes" +%Y-%m-%dT%H:%M:%SZ)
  monitor=$(date -u -d "$MONITOR_HOURS hours" +%Y-%m-%dT%H:%M:%SZ)
  api_post /api/v1/aircraft "{\"id\":\"$AIRCRAFT_ID\",\"operator_id\":\"$OPERATOR_ID\",\"agent_id\":\"$AGENT_ID\",\"tail_number\":\"SITL-1\",\"name\":\"ArduCopter SITL\",\"model\":\"ArduCopter\",\"manufacturer\":\"ArduPilot\",\"status\":\"active\",\"acceptance_status\":\"accepted\",\"remote_id_status\":\"broadcasting\"}" >/dev/null
  api_post /api/v1/batteries "{\"id\":\"battery-sitl-1\",\"operator_id\":\"$OPERATOR_ID\",\"serial_number\":\"SITL-BATTERY-1\",\"model\":\"SITL\",\"state_of_health\":100,\"cycle_count\":0,\"status\":\"current\"}" >/dev/null
  api_post "/api/v1/aircraft/$AIRCRAFT_ID/battery-installations" "{\"id\":\"installation-sitl-1\",\"battery_id\":\"battery-sitl-1\",\"operator_id\":\"$OPERATOR_ID\"}" >/dev/null
  api_post /api/v1/operational-intents "{\"id\":\"$INTENT_ID\",\"operator_id\":\"$OPERATOR_ID\",\"aircraft_id\":\"$AIRCRAFT_ID\",\"name\":\"SITL observer flight\",\"summary\":\"Live MAVLink flight observed end to end\",\"authorization_path\":\"demo\",\"population_category\":\"cat_1\",\"conformance_required\":true,\"planned_start_at\":\"$start\",\"planned_end_at\":\"$end\"}" >/dev/null
  api_post "/api/v1/operational-intents/$INTENT_ID/volumes" "{\"id\":\"$VOLUME_ID\",\"sequence\":1,\"geojson\":\"{\\\"type\\\":\\\"Polygon\\\",\\\"coordinates\\\":[[[149.155237,-35.373262],[149.175237,-35.373262],[149.175237,-35.353262],[149.155237,-35.353262],[149.155237,-35.373262]]]}\",\"min_altitude_m\":0,\"max_altitude_m\":1000,\"altitude_ref\":\"msl\",\"starts_at\":\"$start\",\"ends_at\":\"$end\",\"volume_type\":\"loiter\"}" >/dev/null
  api_post "/api/v1/operational-intents/$INTENT_ID/submit" >/dev/null
  api_post "/api/v1/operational-intents/$INTENT_ID/preflight/evaluate" >"$RUN_DIR/preflight.json"
  api_post "/api/v1/operational-intents/$INTENT_ID/deconfliction/check" >"$RUN_DIR/deconfliction.json"
  api_post "/api/v1/operational-intents/$INTENT_ID/accept" >/dev/null
  api_post "/api/v1/operational-intents/$INTENT_ID/flights" "{\"id\":\"$FLIGHT_ID\",\"operator_id\":\"$OPERATOR_ID\",\"mission_type\":\"sitl\"}" >/dev/null
  api_post "/api/v1/operational-intents/$INTENT_ID/activate" >/dev/null
  api_post "/api/v1/flights/$FLIGHT_ID/start" >/dev/null
  "$RUN_DIR/bin/control" activate \
    --ca "$RUN_DIR/tls/ca.crt" --cert "$RUN_DIR/tls/bootstrap.crt" --key "$RUN_DIR/tls/bootstrap.key" \
    --assignment-id "$ASSIGNMENT_ID" --operator-id "$OPERATOR_ID" --aircraft-id "$AIRCRAFT_ID" \
    --agent-id "$AGENT_ID" --flight-id "$FLIGHT_ID" --intent-id "$INTENT_ID" --intent-version 1 \
    --volume-id "$VOLUME_ID" --planned-start "$start" --planned-end "$end" --monitor-until "$monitor"
  printf '%s\n' "$now" >"$RUN_DIR/activated-at"
  printf '%s\n' "$end" >"$RUN_DIR/planned-end"
  echo "SITL operation is active; planned end $end, monitoring authority $monitor"
}

up() {
  require_safe_run_dir
  for command in docker curl go flutter openssl setsid tmux; do require_command "$command"; done
  if [[ -d "$RUN_DIR" ]]; then
    stop_processes
  fi
  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    tmux send-keys -t "$TMUX_SESSION" C-c
    sleep 2
  fi
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
  for port in 8080 7357 50050 50051 50052 2113; do require_free_port "$port"; done
  docker compose -p aero-arc-sitl-observer -f "$SCRIPT_DIR/compose.yaml" down --volumes --remove-orphans >/dev/null 2>&1 || true
  rm -rf -- "$RUN_DIR"
  mkdir -p "$RUN_DIR/logs" "$RUN_DIR/pids"
  generate_tls
  generate_configs
  docker compose -p aero-arc-sitl-observer -f "$SCRIPT_DIR/compose.yaml" up -d --wait
  build_binaries
  start_process registry "$RUN_DIR/bin/registry" --backend memory --grpc-listen-address 127.0.0.1 --grpc-listen-port 50051 --conformance-ttl 30s
  wait_port Registry 50051
  start_process relay "$RUN_DIR/bin/relay" --config-path "$RUN_DIR/config/relay.yaml" --grpc-port 50050 --tls-cert-path "$RUN_DIR/tls/relay.crt" --tls-key-path "$RUN_DIR/tls/relay.key"
  wait_port Relay 50050
  start_process conformance "$RUN_DIR/bin/conformance" --config-path "$RUN_DIR/config/conformance.yaml"
  wait_port Conformance 50052
  start_process api env AERO_API_ADDR=127.0.0.1:8080 AERO_API_DURABLE_STORE=memory AERO_API_AIRSPACE_PROVIDERS=local AERO_API_TELEMETRY_STORE=influxdb AERO_API_REPLAY_STORE=memory AERO_API_INFLUXDB_HOST=http://127.0.0.1:18181 AERO_API_INFLUXDB_TOKEN=local-development-no-auth AERO_API_INFLUXDB_DATABASE=aero_arc AERO_API_REGISTRY_MODE=grpc AERO_API_REGISTRY_ADDR=127.0.0.1:50051 AERO_API_SEED= "$RUN_DIR/bin/api" start
  wait_http API "$API_URL/readyz"
  start_process agent env AERO_ARC_API_KEY="$AGENT_TOKEN" "$RUN_DIR/bin/agent" --server-address 127.0.0.1 --server-port 50050 --skip-tls-verification --debug --wal-path "$RUN_DIR/agent-wal.db" --wal-flush-timeout 250ms
  tmux new-session -d -s "$TMUX_SESSION" "cd '$ARDUPILOT_SOURCE/ArduCopter' && '$SIM_VEHICLE' -v ArduCopter --no-rebuild --console --out=udp:127.0.0.1:14550"
  sleep 5
  start_process ops make -C "$OPS_DIR" web API_BASE_URL="$API_URL" WEB_HOST=127.0.0.1 WEB_PORT=7357
  wait_http Ops "$OPS_URL"
  activate
  status
  if [[ "${AERO_ARC_SITL_FOREGROUND:-0}" == 1 ]]; then
    echo "SITL observer stack is running in the foreground; press Ctrl-C to release this terminal."
    while kill -0 "$(<"$RUN_DIR/pids/api.pid")" 2>/dev/null; do
      sleep 5
    done
    echo "API process exited; see $RUN_DIR/logs/api.log" >&2
    return 1
  fi
}

aircraft_command() {
  local action=${1:-}
  [[ "$action" == arm || "$action" == disarm ]] || { echo "aircraft-command requires arm or disarm" >&2; exit 2; }
  "$RUN_DIR/bin/control" aircraft-command \
    --ca "$RUN_DIR/tls/ca.crt" --cert "$RUN_DIR/tls/bootstrap.crt" --key "$RUN_DIR/tls/bootstrap.key" \
    --agent-id "$AGENT_ID" --aircraft-id "$AIRCRAFT_ID" --command-id "sitl-$action-$(date +%s%N)" --action "$action"
}

demo_flight() {
  tmux has-session -t "$TMUX_SESSION"
  tmux send-keys -t "$TMUX_SESSION" "mode guided" Enter
  sleep 2
  tmux send-keys -t "$TMUX_SESSION" "arm throttle" Enter
  sleep 3
  tmux send-keys -t "$TMUX_SESSION" "takeoff 15" Enter
  sleep 12
  tmux send-keys -t "$TMUX_SESSION" "guided -35.362500 149.166000 20" Enter
  echo "SITL is taking off and moving to the demo waypoint; it remains active for observation."
}

land() {
  tmux has-session -t "$TMUX_SESSION"
  tmux send-keys -t "$TMUX_SESSION" "mode land" Enter
  echo "LAND sent through MAVProxy. Wait for landing and disarm before make sitl-complete."
}

complete() {
  api_post "/api/v1/operational-intents/$INTENT_ID/complete" >/dev/null
  "$RUN_DIR/bin/control" clear \
    --ca "$RUN_DIR/tls/ca.crt" --cert "$RUN_DIR/tls/bootstrap.crt" --key "$RUN_DIR/tls/bootstrap.key" \
    --agent-id "$AGENT_ID" --flight-id "$FLIGHT_ID" --command-id "sitl-$FLIGHT_ID-clear"
  echo "Intent completed and Agent operation context cleared."
}

status() {
  echo "Ops: $OPS_URL"
  echo "API: $API_URL"
  curl --silent --show-error "$API_URL/api/v1/aircraft/$AIRCRAFT_ID/state" || true
  echo
  curl --silent --show-error "$API_URL/api/v1/operations" || true
  echo
}

console() {
  exec tmux attach-session -t "$TMUX_SESSION"
}

down() {
  require_safe_run_dir
  stop_processes
  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    tmux send-keys -t "$TMUX_SESSION" C-c
    sleep 2
  fi
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
  docker compose -p aero-arc-sitl-observer -f "$SCRIPT_DIR/compose.yaml" down --remove-orphans
  echo "Aero Arc SITL observer processes stopped; runtime artifacts remain in $RUN_DIR"
}

case "${1:-}" in
  up) up ;;
  activate) activate ;;
  status) status ;;
  aircraft-command) aircraft_command "${2:-}" ;;
  demo-flight) demo_flight ;;
  land) land ;;
  complete) complete ;;
  console) console ;;
  down) down ;;
  *) echo "usage: $0 {up|status|activate|aircraft-command arm|aircraft-command disarm|demo-flight|land|complete|console|down}" >&2; exit 2 ;;
esac
