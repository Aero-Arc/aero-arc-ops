#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RUN_DIR='/tmp/aero-arc-sitl-test runtime'
source "$SCRIPT_DIR/history-environment.sh"
[[ "$AERO_API_CONFORMANCE_ADDR" == 127.0.0.1:50052 ]]
[[ "$AERO_API_CONFORMANCE_CA_FILE" == "$RUN_DIR/tls/ca.crt" ]]
[[ "$AERO_API_CONFORMANCE_CERT_FILE" == "$RUN_DIR/tls/bootstrap.crt" ]]
[[ "$AERO_API_CONFORMANCE_KEY_FILE" == "$RUN_DIR/tls/bootstrap.key" ]]
[[ "$AERO_API_CONFORMANCE_SERVER_NAME" == localhost ]]
printf 'Conformance history demo environment tests passed.\n'
