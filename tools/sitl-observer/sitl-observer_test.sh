#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEST_RUN_DIR=$(mktemp -d /tmp/aero-arc-sitl-test-XXXXXX)
trap 'rm -rf -- "$TEST_RUN_DIR"' EXIT

export AERO_ARC_SITL_OBSERVER_SOURCE_ONLY=1
export AERO_ARC_SITL_RUN_DIR=$TEST_RUN_DIR
unset AERO_ARC_SITL_STREAM_RATE_HZ
# shellcheck source=sitl-observer.sh
source "$SCRIPT_DIR/sitl-observer.sh"

[[ "$SITL_STREAM_RATE_HZ" == 4 ]]
validate_sitl_stream_rate
SITL_STREAM_RATE_HZ=7
ARDUPILOT_SOURCE='/tmp/ardupilot source'
SIM_VEHICLE='/tmp/sim vehicle.py'
expected_command='cd /tmp/ardupilot\ source/ArduCopter && exec /tmp/sim\ vehicle.py -v ArduCopter --no-rebuild --console --out=udp:127.0.0.1:14550 --mavproxy-args=--streamrate=7'
[[ "$(sitl_vehicle_command)" == "$expected_command" ]]
for invalid_rate in 0 4.5 51 '4; touch /tmp/unsafe'; do
  SITL_STREAM_RATE_HZ=$invalid_rate
  if validate_sitl_stream_rate 2>/dev/null; then
    echo "invalid SITL stream rate was accepted: $invalid_rate" >&2
    exit 1
  fi
done
SITL_STREAM_RATE_HZ=4

CURL_CALLS_FILE=$TEST_RUN_DIR/curl-calls
RECONCILE_COUNT_FILE=$TEST_RUN_DIR/reconcile-count
printf '0\n' >"$RECONCILE_COUNT_FILE"

curl() {
  local output_file= url= method=GET has_body=0
  while (($#)); do
    case "$1" in
      --output)
        output_file=$2
        shift 2
        ;;
      -X)
        method=$2
        shift 2
        ;;
      --data | --data-binary | --data-raw)
        has_body=1
        shift 2
        ;;
      http://* | https://*)
        url=$1
        shift
        ;;
      *) shift ;;
    esac
  done
  printf '%s %s body=%s\n' "$method" "$url" "$has_body" >>"$CURL_CALLS_FILE"
  case "$url" in
    */missions/current)
      printf '{"id":"mission-1","mission_digest":"%064d"}\n' 0 >"$output_file"
      ;;
    */missions/mission-1/deploy)
      printf '{"deployment":{"id":"deployment-1","status":"pending","mission_id":"mission-1","mission_digest":"%064d","message":"waiting"},"replayed":false}\n' 0 >"$output_file"
      printf '202'
      ;;
    */mission-deployments/deployment-1/reconcile)
      local count
      count=$(<"$RECONCILE_COUNT_FILE")
      count=$((count + 1))
      printf '%s\n' "$count" >"$RECONCILE_COUNT_FILE"
      if [[ "$count" -eq 1 ]]; then
        printf '{"deployment":{"id":"deployment-1","status":"temporary_error","mission_id":"mission-1","mission_digest":"%064d","message":"agent not ready"},"replayed":false}\n' 0 >"$output_file"
      else
        printf '{"deployment":{"id":"deployment-1","status":"already_applied","mission_id":"mission-1","mission_digest":"%064d","onboard_mission_digest":"%064d","uploaded_item_count":0},"replayed":false}\n' 0 0 >"$output_file"
      fi
      printf '200'
      ;;
    *)
      echo "unexpected curl URL: $url" >&2
      return 1
      ;;
  esac
}

sleep() { :; }

CLEANUP_CALLS_FILE=$TEST_RUN_DIR/cleanup-calls
if (
  set +e
  stop_processes() { printf 'stop-processes\n' >>"$CLEANUP_CALLS_FILE"; }
  tmux() {
    printf 'tmux %s\n' "$*" >>"$CLEANUP_CALLS_FILE"
    return 0
  }
  docker() {
    printf 'docker %s\n' "$*" >>"$CLEANUP_CALLS_FILE"
    return 0
  }
  false
  cleanup_failed_up
); then
  echo "failed startup cleanup unexpectedly succeeded" >&2
  exit 1
fi
grep --fixed-strings --quiet 'stop-processes' "$CLEANUP_CALLS_FILE"
grep --fixed-strings --quiet "tmux send-keys -t $TMUX_SESSION C-c" "$CLEANUP_CALLS_FILE"
grep --fixed-strings --quiet "tmux kill-session -t $TMUX_SESSION" "$CLEANUP_CALLS_FILE"
grep --fixed-strings --quiet \
  "docker compose -p aero-arc-sitl-observer -f $SCRIPT_DIR/compose.yaml down --volumes --remove-orphans" \
  "$CLEANUP_CALLS_FILE"

if deploy_mission; then
  echo "initial deployment unexpectedly completed" >&2
  exit 1
else
  [[ $? -eq 1 ]]
fi
if resume_mission_deployment; then
  echo "first reconciliation unexpectedly completed" >&2
  exit 1
else
  [[ $? -eq 1 ]]
fi
result=$(wait_deploy_mission deployment-1)
jq -e '.deployment_id == "deployment-1" and .status == "already_applied"' <<<"$result" >/dev/null
[[ $(grep -c '/missions/mission-1/deploy' "$CURL_CALLS_FILE") -eq 1 ]]
[[ $(grep -c '/mission-deployments/deployment-1/reconcile' "$CURL_CALLS_FILE") -eq 2 ]]
! grep '/mission-deployments/deployment-1/reconcile.*body=1' "$CURL_CALLS_FILE" >/dev/null

echo "sitl-observer stream-rate and durable deployment reconciliation tests passed"
