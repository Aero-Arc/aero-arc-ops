#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEST_RUN_DIR=$(mktemp -d /tmp/aero-arc-sitl-test-XXXXXX)
trap 'rm -rf -- "$TEST_RUN_DIR"' EXIT

export AERO_ARC_SITL_OBSERVER_SOURCE_ONLY=1
export AERO_ARC_SITL_RUN_DIR=$TEST_RUN_DIR
unset AERO_ARC_SITL_STREAM_RATE_HZ
unset AERO_ARC_SITL_WEB_MODE
# shellcheck source=sitl-observer.sh
source "$SCRIPT_DIR/sitl-observer.sh"

[[ "$OPS_WEB_MODE" == release ]]
validate_ops_web_mode
for mode in debug profile release; do
  OPS_WEB_MODE=$mode
  validate_ops_web_mode
done
OPS_WEB_MODE='invalid'
if validate_ops_web_mode 2>/dev/null; then
  echo 'invalid web mode was accepted' >&2
  exit 1
fi
OPS_WEB_MODE=release
# Stub in a subshell so subsequent process tests retain the real launcher.
(
  start_process() {
    [[ "$1" == ops && "$2" == make ]]
    [[ "${!#}" == WEB_MODE=release ]]
  }
  start_ops
)

[[ "$SITL_STREAM_RATE_HZ" == 4 ]]
validate_sitl_stream_rate
SITL_STREAM_RATE_HZ=7
ARDUPILOT_SOURCE='/tmp/ardupilot source'
SIM_VEHICLE='/tmp/sim vehicle.py'
printf -v expected_command 'cd /tmp/ardupilot\\ source/ArduCopter && exec env -u DISPLAY -u WAYLAND_DISPLAY PYTHONUNBUFFERED=1 /tmp/sim\\ vehicle.py -v ArduCopter --no-rebuild --no-extra-ports --use-dir %q --add-param-file %q --out=udp:127.0.0.1:14550 --mavproxy-args=--streamrate=7' "$RUN_DIR/sitl" "$SCRIPT_DIR/ui-command-defaults.parm"
[[ "$(sitl_vehicle_command)" == "$expected_command" ]]
# Startup supplies AUTO and recovery options, retaining normal arming checks.
[[ $(sed '/^#/d; /^$/d' "$SCRIPT_DIR/ui-command-defaults.parm") == $'AUTO_OPTIONS 3\nRTL_ALT_FINAL 0\nDISARM_DELAY 30' ]]
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
      if [[ "$count" -le 16 ]]; then
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

# A retained tmux pane is not a live simulator. pane_dead must fail closed.
(
  tmux() {
    case "$1" in
      has-session) return 0 ;;
      display-message) printf '1:2\n'; return 0 ;;
    esac
    return 0
  }
  if sitl_session_alive; then
    echo 'dead SITL pane was reported live' >&2
    exit 1
  fi
)
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
[[ $(grep -c '/mission-deployments/deployment-1/reconcile' "$CURL_CALLS_FILE") -eq 17 ]]
! grep '/mission-deployments/deployment-1/reconcile.*body=1' "$CURL_CALLS_FILE" >/dev/null

# The same durable deployment must survive more polls than the old synchronous
# 15-attempt budget. No poll may create a second deployment.
echo "sitl-observer headless startup and asynchronous deployment reconciliation tests passed"

# Command helpers must use authenticated durable submission and wait for evidence.
(
  calls="$TEST_RUN_DIR/command-calls"
  mkdir -p "$RUN_DIR/logs"
  printf 'AP: EKF3 IMU0 is using GPS\n' >"$RUN_DIR/logs/sitl.log"

  api_post_file() {
    [[ "$1" == "/api/v1/flights/$FLIGHT_ID/commands" ]]
    local type
    type=$(jq -er '.type' "$2")
    [[ "$3" == "sitl-$FLIGHT_ID-$type" ]]
    [[ $(jq 'keys | length' "$2") == 1 ]]
    printf '%s\n' "$type" >>"$calls"
    printf '{"id":"command-%s","state":"accepted"}' "$type"
  }
  curl() {
    if [[ "$*" == *"/state"* ]]; then
      printf '{"telemetry":{"position":{"status":"fresh"},"gps":{"status":"fresh","gps_fix_type":"gps_fix_type_3d_fix"}}}'
      return
    fi
    [[ "$*" == *"Authorization: Bearer $MISSION_DEPLOY_TOKEN"* ]]
    [[ "$*" == *"/commands/command-"* ]]
    printf '{"state":"applied","observation_state":"observed"}'
  }
  tmux() {
    if [[ "$1" == display-message ]]; then printf '0:\n'; return 0; fi
    echo 'legacy simulator command unexpectedly used' >&2; return 1
  }
  mission_run
  [[ $(cat "$calls") == $'ARM\nMISSION_START' ]]
  land
  [[ $(tail -1 "$calls") == LAND ]]
)
# Completion 404 and asynchronous progress must not be presented as finished.
(
  count_file="$TEST_RUN_DIR/completion-count"
  printf '0' >"$count_file"
  curl() {
    [[ "$*" == *"Authorization: Bearer $MISSION_DEPLOY_TOKEN"* ]]
    local output= count
    while (($#)); do
      if [[ "$1" == --output ]]; then output=$2; shift 2; else shift; fi
    done
    count=$(<"$count_file"); count=$((count+1)); printf '%s' "$count" >"$count_file"
    case "$count" in
      1) return 28 ;;
      2) printf '{}' >"$output"; printf 503 ;;
      3) printf '{}' >"$output"; printf 404 ;;
      4) printf '{"state":"finalizing"}' >"$output"; printf 200 ;;
      *) printf '{"state":"complete"}' >"$output"; printf 200 ;;
    esac
  }
  complete
  [[ $(cat "$count_file") == 5 ]]
)
echo 'durable command and completion helper tests passed'

# Readiness fails closed before any command when fresh position is missing.
(
  sleep() { :; }
  curl() { printf '{"telemetry":{"position":{"status":"stale"},"gps":{"status":"fresh","gps_fix_type":"gps_fix_type_rtk_fixed"}}}'; }
  durable_command() { echo 'command unexpectedly submitted before navigation readiness' >&2; exit 99; }
  if mission_run; then echo 'stale navigation was accepted' >&2; exit 1; fi
)

# A timed-out command POST retains immutable request bytes/key for exact retry.
(
  post_log="$TEST_RUN_DIR/timed-posts"
  curl() {
    [[ "$*" == *"--max-time 10"* ]]
    if [[ "$*" == *"-X POST"* ]]; then
      printf '%s\n' "$*" >>"$post_log"
      if [[ $(wc -l <"$post_log") == 1 ]]; then return 28; fi
      local output='' previous=''
      for argument in "$@"; do
        if [[ "$previous" == --output ]]; then output=$argument; fi
        previous=$argument
      done
      printf '{"id":"stable-command","state":"accepted"}' >"$output"
      printf '202'
    else
      printf '{"state":"applied","observation_state":"observed"}'
    fi
  }
  if durable_command RTL; then echo 'timeout claimed acceptance' >&2;exit 1;fi
  before=$(sha256sum "$RUN_DIR/command-RTL-request.json")
  durable_command RTL
  [[ "$before" == "$(sha256sum "$RUN_DIR/command-RTL-request.json")" ]]
  [[ $(sed -n '1p' "$post_log") == "$(sed -n '2p' "$post_log")" ]]
)

# Evidence polling survives a transport failure without resubmitting the command.
(
  calls="$TEST_RUN_DIR/poll-recovery"
  api_post_file() { printf '{"id":"retained-command"}'; }
  curl() {
    [[ "$*" == *"--max-time 10 --connect-timeout 5"* ]]
    [[ "$*" == *"/commands/retained-command"* ]]
    if [[ ! -f "$calls" ]]; then touch "$calls";return 28;fi
    printf '{"state":"applied","observation_state":"observed"}'
  }
  durable_command LAND
)
# Completion timeout is a wall-clock deadline, including failed requests.
(
  COMPLETION_TIMEOUT=2
  SECONDS=0
  curl() { [[ "$*" == *"--max-time 2"* ]];SECONDS=3;return 28; }
  # Command substitution runs curl in a subshell; advance the caller at retry.
  sleep() { SECONDS=3; }
  if complete;then echo 'completion timeout reported success' >&2;exit 1;fi
)

# A retained dead pane blocks demo actions before they submit authority.
(
  simulated_pane_state='0:'
  tmux() {
    [[ "$1" == display-message && "$4" == "$TMUX_SESSION:" ]] || return 1
    printf '%s\n' "$simulated_pane_state"
  }
  sitl_session_alive
  simulated_pane_state='1:2'
  if sitl_session_alive; then exit 1; fi
  api_post() { echo 'dead simulator mutated API state' >&2; exit 99; }
  if demo_flight; then exit 1; fi
  if mission_run; then exit 1; fi
)
