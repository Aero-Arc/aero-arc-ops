#!/usr/bin/env bash
# Sourced by the local demo runner after its TLS files have been generated.
: "${RUN_DIR:?RUN_DIR must identify the local demo runtime}"
export AERO_API_CONFORMANCE_ADDR=127.0.0.1:50052
export AERO_API_CONFORMANCE_CA_FILE="$RUN_DIR/tls/ca.crt"
export AERO_API_CONFORMANCE_CERT_FILE="$RUN_DIR/tls/bootstrap.crt"
export AERO_API_CONFORMANCE_KEY_FILE="$RUN_DIR/tls/bootstrap.key"
export AERO_API_CONFORMANCE_SERVER_NAME=localhost
