#!/usr/bin/env bash
set -e

echo "🔹 Starting Towonel Agent inside Home Assistant OS..."

CONFIG_PATH="/data/options.json"

if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "❌ ERROR: Configuration file not found at $CONFIG_PATH!"
    exit 1
fi

INVITE_TOKEN=$(jq -r '.invite_token' "$CONFIG_PATH")
AGENT_SERVICES=$(jq -r '.agent_services' "$CONFIG_PATH")
AGENT_TCP_SERVICES=$(jq -r '.agent_tcp_services // "[]"' "$CONFIG_PATH")
AGENT_UDP_SERVICES=$(jq -r '.agent_udp_services // "[]"' "$CONFIG_PATH")
RELAY_URL=$(jq -r '.relay_url // empty' "$CONFIG_PATH")
LOG_LEVEL=$(jq -r '.log_level // "info"' "$CONFIG_PATH")
CUSTOM_ENV_VARS=$(jq -r '.custom_env_vars // [] | .[]' "$CONFIG_PATH")

if [[ -z "$INVITE_TOKEN" || "$INVITE_TOKEN" == "null" || \
      -z "$AGENT_SERVICES" || "$AGENT_SERVICES" == "null" ]]; then
    echo "❌ ERROR: Missing required configuration values (invite_token / agent_services)!"
    exit 1
fi

echo "✅ Configuration loaded:"
echo "  TOWONEL_INVITE_TOKEN=[REDACTED]"
echo "  TOWONEL_AGENT_SERVICES=$AGENT_SERVICES"
echo "  RUST_LOG=$LOG_LEVEL"

export TOWONEL_INVITE_TOKEN="$INVITE_TOKEN"
export TOWONEL_AGENT_SERVICES="$AGENT_SERVICES"
export TOWONEL_AGENT_TCP_SERVICES="$AGENT_TCP_SERVICES"
export TOWONEL_AGENT_UDP_SERVICES="$AGENT_UDP_SERVICES"
export TOWONEL_AGENT_HEALTH_LISTEN_ADDR="127.0.0.1:9090"
export RUST_LOG="$LOG_LEVEL"

if [[ -n "$RELAY_URL" ]]; then
    export TOWONEL_AGENT_RELAY_URL="$RELAY_URL"
fi

# Persistent storage path for HA add-ons
export HOME="/data"

STOP_REQUESTED=0
AGENT_PID=""

handle_shutdown() {
    STOP_REQUESTED=1
    echo "🔹 Shutdown requested, stopping Towonel Agent..."
    if [[ -n "$AGENT_PID" ]] && kill -0 "$AGENT_PID" 2>/dev/null; then
        kill -SIGTERM "$AGENT_PID" 2>/dev/null || true
        wait "$AGENT_PID" 2>/dev/null || true
    fi
}
trap handle_shutdown SIGTERM SIGINT

# Safely process custom environment variables (as in the Newt add-on)
if [[ -n "$CUSTOM_ENV_VARS" ]]; then
    echo "✅ Custom Environment Variables:"
    while IFS= read -r env_var; do
        [[ -z "$env_var" ]] && continue
        if [[ ! "$env_var" =~ ^[A-Z_][A-Z0-9_]*=.+$ ]] || [[ "$env_var" == *$'\n'* ]] || [[ "$env_var" == *$'\r'* ]]; then
            echo "⚠️ Skipping invalid custom env var format"
            continue
        fi
        var_name="${env_var%%=*}"
        # Protected variables: either they control run.sh itself
        # (PATH/HOME/LD_*), or they would silently override values already
        # validated from the add-on configuration above.
        case "$var_name" in
            PATH|HOME|LD_*|TOWONEL_INVITE_TOKEN|TOWONEL_AGENT_SERVICES|TOWONEL_AGENT_TCP_SERVICES|TOWONEL_AGENT_UDP_SERVICES|TOWONEL_AGENT_HEALTH_LISTEN_ADDR)
                echo "  ⚠️ Skipping protected variable: ${var_name}"
                continue
                ;;
        esac
        echo "  ${var_name}=[REDACTED]"
        # shellcheck disable=SC2163
        export "$env_var"
    done <<< "$CUSTOM_ENV_VARS"
fi

# Auto-reconnect loop
while true; do
    if [[ "$STOP_REQUESTED" -eq 1 ]]; then
        echo "🔹 Exiting reconnect loop"
        exit 0
    fi

    echo "🔹 Starting Towonel Agent..."
    /usr/bin/towonel-agent &
    AGENT_PID=$!

    set +e
    wait "$AGENT_PID"
    AGENT_EXIT_CODE=$?
    set -e

    AGENT_PID=""

    if [[ "$STOP_REQUESTED" -eq 1 ]]; then
        echo "🔹 Towonel Agent stopped due to shutdown signal"
        exit 0
    fi

    echo "⚠️ Towonel Agent stopped with exit code ${AGENT_EXIT_CODE}! Waiting 5 seconds before reconnecting..."
    sleep 5 &
    wait $! 2>/dev/null || true
done
