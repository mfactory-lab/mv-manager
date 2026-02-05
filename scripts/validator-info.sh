#!/bin/bash
# Monad Validator Info

set -euo pipefail

ENV_FILTER="${1:-}"
HOST_FILTER="${2:-}"
INV="inventory/local.yml"

G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[34m'; C='\033[36m'; N='\033[0m'

get_validators() {
    local jq_filter='.value.type == "validator"'
    [ -n "$ENV_FILTER" ] && jq_filter="$jq_filter and .value.env == \"$ENV_FILTER\""
    [ -n "$HOST_FILTER" ] && jq_filter="$jq_filter and .key == \"$HOST_FILTER\""

    ansible-inventory -i "$INV" --list 2>/dev/null | \
        jq -r "._meta.hostvars | to_entries | map(select($jq_filter)) | .[] | \"\(.key)|\(.value.ansible_host)\""
}

for entry in $(get_validators); do
    NODE_NAME=$(echo "$entry" | cut -d'|' -f1)
    IP=$(echo "$entry" | cut -d'|' -f2)

    echo -e "\n${B}━━━ ${G}$NODE_NAME${N} ${B}($IP) ━━━${N}"

    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "root@${IP}" bash -s << 'REMOTE_SCRIPT'
MONAD_HOME="/opt/monad-consensus"
KEY_DIR="${MONAD_HOME}/key"
CONFIG_FILE="${MONAD_HOME}/config/node.toml"
LOG_FILE="${MONAD_HOME}/log/monad-consensus.log"

G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[34m'; C='\033[36m'; N='\033[0m'

print_section() { echo -e "\n${B}─── $1 ───${N}"; }
print_ok() { echo -e "  ${G}✓${N} $1: ${C}$2${N}"; }
print_warn() { echo -e "  ${Y}!${N} $1: $2"; }
print_err() { echo -e "  ${R}✗${N} $1: $2"; }
print_info() { echo -e "  $1: ${C}$2${N}"; }

# --- Keys ---
print_section "KEYS"
KEYSTORE_PASS=$(grep KEYSTORE_PASSWORD "${MONAD_HOME}/environment/secrets.env" 2>/dev/null | cut -d"'" -f2)

if [ -f "${KEY_DIR}/id-secp.pub" ]; then
    print_ok "SECP" "$(cat ${KEY_DIR}/id-secp.pub)"
elif [ -f "${KEY_DIR}/id-secp" ] && [ -n "$KEYSTORE_PASS" ]; then
    SECP_PUB=$(/usr/local/bin/monad-keystore recover --keystore-path "${KEY_DIR}/id-secp" --password "$KEYSTORE_PASS" --key-type secp 2>/dev/null | grep "public key:" | awk '{print $NF}')
    if [ -n "$SECP_PUB" ]; then
        echo "$SECP_PUB" > "${KEY_DIR}/id-secp.pub" 2>/dev/null || true
        print_ok "SECP" "$SECP_PUB"
    else
        print_warn "SECP" "could not extract"
    fi
else
    [ -f "${KEY_DIR}/id-secp" ] && print_warn "SECP" "no password" || print_err "SECP" "not found"
fi

if [ -f "${KEY_DIR}/id-bls.pub" ]; then
    print_ok "BLS" "$(cat ${KEY_DIR}/id-bls.pub)"
elif [ -f "${KEY_DIR}/id-bls" ] && [ -n "$KEYSTORE_PASS" ]; then
    BLS_PUB=$(/usr/local/bin/monad-keystore recover --keystore-path "${KEY_DIR}/id-bls" --password "$KEYSTORE_PASS" --key-type bls 2>/dev/null | grep "public key:" | awk '{print $NF}')
    if [ -n "$BLS_PUB" ]; then
        echo "$BLS_PUB" > "${KEY_DIR}/id-bls.pub" 2>/dev/null || true
        print_ok "BLS" "$BLS_PUB"
    else
        print_warn "BLS" "could not extract"
    fi
else
    [ -f "${KEY_DIR}/id-bls" ] && print_warn "BLS" "no password" || print_err "BLS" "not found"
fi

# --- Config ---
print_section "CONFIG"
if [ -f "$CONFIG_FILE" ]; then
    print_info "Node Name" "$(grep -E '^node_name' $CONFIG_FILE 2>/dev/null | cut -d'"' -f2)"
    print_info "Chain ID" "$(grep -E '^chain_id' $CONFIG_FILE 2>/dev/null | awk '{print $3}')"
    print_info "Beneficiary" "$(grep -E '^beneficiary' $CONFIG_FILE 2>/dev/null | cut -d'"' -f2)"
else
    print_err "Config" "not found"
fi

# --- Sync Status ---
print_section "SYNC STATUS"
if [ -f "$LOG_FILE" ]; then
    LATEST_LOG=$(tail -500 "$LOG_FILE" 2>/dev/null)
    STATESYNC_MSG=$(echo "$LATEST_LOG" | grep "high qc too far ahead" | tail -1 || true)
    BLOCKSYNC=$(echo "$LATEST_LOG" | grep -c "blocksync" || echo "0")
    ROUND=$(echo "$LATEST_LOG" | grep -oE '"round":"?[0-9]+' | tail -1 | grep -oE '[0-9]+')

    if [ -n "$STATESYNC_MSG" ]; then
        HIGH_QC=$(echo "$STATESYNC_MSG" | grep -oE 'highqc: [0-9]+' | grep -oE '[0-9]+')
        LOCAL=$(echo "$STATESYNC_MSG" | grep -oE 'block-tree root [0-9]+' | grep -oE '[0-9]+')
        [ -n "$HIGH_QC" ] && print_info "Network" "$HIGH_QC"
        [ -n "$LOCAL" ] && print_info "Local" "$LOCAL"
        [ -n "$HIGH_QC" ] && [ -n "$LOCAL" ] && print_warn "Status" "syncing ($((HIGH_QC - LOCAL)) behind)"
    elif [ -n "$ROUND" ]; then
        print_info "Round" "$ROUND"
        print_ok "Status" "synced"
    elif [ "$BLOCKSYNC" -gt 10 ]; then
        print_warn "Status" "block syncing..."
    else
        print_warn "Status" "connecting..."
    fi
else
    print_err "Logs" "not found"
fi

# --- Service ---
print_section "SERVICE"
if systemctl is-active --quiet monad-consensus 2>/dev/null; then
    print_ok "monad-consensus" "running"
    print_info "Since" "$(systemctl show monad-consensus --property=ActiveEnterTimestamp 2>/dev/null | cut -d'=' -f2 | cut -d' ' -f1-2)"
else
    print_err "monad-consensus" "not running"
fi

# --- Resources ---
print_section "RESOURCES"
print_info "Disk" "$(df -h $MONAD_HOME 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
print_info "Memory" "$(free -h | awk '/Mem:/ {print $3 "/" $2}')"
print_info "Load" "$(uptime | awk -F'load average:' '{print $2}' | xargs)"

# --- Network ---
print_section "NETWORK"
P2P_PORT=$(grep -E "^bind_address_port" "$CONFIG_FILE" 2>/dev/null | awk '{print $3}' || echo "8000")
if ss -lnp 2>/dev/null | grep -q ":${P2P_PORT} "; then
    print_ok "P2P" "$P2P_PORT (listening)"
else
    print_err "P2P" "$P2P_PORT (not listening)"
fi

echo ""
REMOTE_SCRIPT
    then
        echo -e "  ${R}✗ SSH connection failed${N}\n"
    fi

done
