#!/usr/bin/env bash
set -e

echo "🔹 Starting Towonel Agent inside Home Assistant OS..."

CONFIG_PATH="/data/options.json"

if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "❌ ERROR: Configuration file not found at $CONFIG_PATH!"
    exit 1
fi

# Option keys match the real TOWONEL_* env var names 1:1 (as in the Newt
# add-on), so they're read and re-exported under the same name.
TOWONEL_INVITE_TOKEN=$(jq -r '.TOWONEL_INVITE_TOKEN' "$CONFIG_PATH")
TOWONEL_AGENT_SERVICES=$(jq -r '.TOWONEL_AGENT_SERVICES' "$CONFIG_PATH")
TOWONEL_AGENT_TCP_SERVICES=$(jq -r '.TOWONEL_AGENT_TCP_SERVICES // "[]"' "$CONFIG_PATH")
TOWONEL_AGENT_UDP_SERVICES=$(jq -r '.TOWONEL_AGENT_UDP_SERVICES // "[]"' "$CONFIG_PATH")
TOWONEL_AGENT_TRUSTED_EDGES=$(jq -r '.TOWONEL_AGENT_TRUSTED_EDGES // empty' "$CONFIG_PATH")
RUST_LOG=$(jq -r '.RUST_LOG // "info"' "$CONFIG_PATH")
CUSTOM_ENV_VARS=$(jq -r '.custom_env_vars // [] | .[]' "$CONFIG_PATH")

if [[ -z "$TOWONEL_INVITE_TOKEN" || "$TOWONEL_INVITE_TOKEN" == "null" || \
      -z "$TOWONEL_AGENT_SERVICES" || "$TOWONEL_AGENT_SERVICES" == "null" ]]; then
    echo "❌ ERROR: Missing required configuration values (TOWONEL_INVITE_TOKEN / TOWONEL_AGENT_SERVICES)!"
    exit 1
fi

echo "✅ Configuration loaded:"
echo "  TOWONEL_INVITE_TOKEN=[REDACTED]"
echo "  TOWONEL_AGENT_SERVICES=$TOWONEL_AGENT_SERVICES"
echo "  RUST_LOG=$RUST_LOG"

export TOWONEL_INVITE_TOKEN
export TOWONEL_AGENT_SERVICES
export TOWONEL_AGENT_TCP_SERVICES
export TOWONEL_AGENT_UDP_SERVICES
export RUST_LOG

# Optional override — only export when actually set, so an empty/unset
# option doesn't submit an explicit empty override to the hub.
if [[ -n "$TOWONEL_AGENT_TRUSTED_EDGES" && "$TOWONEL_AGENT_TRUSTED_EDGES" != "null" ]]; then
    export TOWONEL_AGENT_TRUSTED_EDGES
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
            PATH|HOME|LD_*|TOWONEL_INVITE_TOKEN|TOWONEL_AGENT_SERVICES|TOWONEL_AGENT_TCP_SERVICES|TOWONEL_AGENT_UDP_SERVICES|TOWONEL_AGENT_TRUSTED_EDGES|RUST_LOG)
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
