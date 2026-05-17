# Monad Validator Manager

[![Monad](https://img.shields.io/badge/Monad-6e54ff?logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTYiIGhlaWdodD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSI4IiBjeT0iOCIgcj0iNyIgZmlsbD0id2hpdGUiLz48L3N2Zz4=&style=for-the-badge)](https://monad.xyz)
[![Ansible](https://img.shields.io/badge/Ansible-2.15%2B-grey?logo=ansible&logoColor=white&style=for-the-badge)](https://docs.ansible.com/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

Deploy Monad validators in minutes, not hours. Ansible automation for the entire lifecycle — setup, monitoring, upgrades, and recovery — on testnet and mainnet.

## Prerequisites

**Target server:**

| Component | Specification |
|-----------|---------------|
| OS | Ubuntu 22.04 / 24.04 |
| CPU | 16+ cores |
| RAM | 32GB minimum |
| Storage | 2TB NVMe (TrieDB) + 500GB (OS/consensus) |
| Network | 1Gbps, static IP |

**Your local machine:**

- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) 2.15+
- Python 3.10+
- `jq` (for Makefile helper scripts)
- SSH key access to target server (root or sudo user)

## Quick Start

```bash
# Clone the repo
git clone https://github.com/pointgroup-labs/mv-manager.git
cd mv-manager

# Install Ansible collections
ansible-galaxy install -r requirements.yml

# Configure secrets
cp group_vars/vault.yml.example group_vars/vault-testnet.yml
vim group_vars/vault-testnet.yml
ansible-vault encrypt group_vars/vault-testnet.yml

# Configure inventory
cp inventory/example.yml inventory/testnet.yml
vim inventory/testnet.yml     # set your server IP

# Test connectivity
make ping

# Deploy
make deploy

# Apply snapshot for fast sync
make snapshot

# Monitor sync progress
make status
```

## Configuration

### Secrets (`group_vars/vault-<env>.yml`)

Copy from the example for each network:

```yaml
# IKM (Initial Key Material) - generates your SECP and BLS keys
vault_secp_ikm: "64_hex_chars"
vault_bls_ikm: "64_hex_chars"

# Keystore password (generate with: openssl rand -base64 32)
vault_keystore_password: "your_password"

# Staking (needed for validator registration)
vault_funded_wallet_private_key: "wallet_with_100k_MON"
vault_beneficiary_address: "0x..."
vault_auth_address: "0x..."

# Telegram alerts (optional — for observability stack)
vault_telegram_bot_token: ""
vault_telegram_chat_id: ""
```

Always encrypt after editing:

```bash
make vault-encrypt          # ENV=testnet by default
make vault-encrypt ENV=mainnet
```

### Inventory (`inventory/<env>.yml`)

Create one per network (gitignored — contains server IPs):

```yaml
all:
  vars:
    env: testnet  # or mainnet

  children:
    monad:
      children:
        validators:
          hosts:
            my-validator:
              ansible_host: "1.2.3.4"
              type: validator
              validator_id: 123
              setup_triedb: true
              register_validator: false

        fullnodes:
          hosts: {}
```

**Multiple validators** — add more hosts under `validators`:

```yaml
        validators:
          hosts:
            validator-01:
              ansible_host: "1.2.3.4"
              type: validator
              validator_id: 123
              setup_triedb: true
            validator-02:
              ansible_host: "5.6.7.8"
              type: validator
              validator_id: 456
              setup_triedb: true
```

Target a specific node with `NODE=`:

```bash
make status NODE=validator-01
make restart NODE=validator-02
```

## How It Works

`make deploy` runs the full deployment pipeline through these Ansible roles:

```
common          → Preflight checks, firewall (UFW), fail2ban, sudoers
prepare_server  → System packages, kernel tuning, hugepages, TrieDB disk
monad-node      → Install monad apt package, node.toml config, systemd service,
                  cruft compat symlinks (ledger/config under monad-bft/)
execution       → Execution layer, statesync socket
rpc             → JSON-RPC server (optional)
validator       → Staking CLI, key generation, registration scripts
fastlane        → MEV sidecar in rootless Docker + socket watcher (opt-in)
monitoring      → Health check scripts, alert thresholds
backup          → Automated backup scripts (daily, 7-day retention)
observability   → Prometheus, Grafana, OTEL collector, custom exporter (opt-in)
```

Each role can run independently using tags:

```bash
ansible-playbook -i inventory/testnet.yml playbooks/deploy-validator.yml --tags monad
```

**Standalone playbooks** for targeted operations:

```
setup-execution.yml      → Just the execution layer
setup-rpc.yml            → Just the JSON-RPC server
setup-fastlane.yml       → Just the FastLane MEV sidecar
setup-observability.yml  → Just the observability stack
snapshot.yml             → Apply chain snapshot
register-validator.yml   → On-chain validator registration
upgrade-node.yml         → Rolling monad package upgrade (serial: 1)
migrate-validator.yml    → Fast migrate validator to new server
maintenance.yml          → restart/stop/start/backup/health (tag-driven)
recovery.yml             → Diagnostics + repair (tag-driven)
```

## Commands

Run `make help` to see all available commands. All commands support `ENV=testnet|mainnet` and `NODE=<name>` to target a specific network or host.

### Deployment

```bash
make bootstrap NAME=foo-testnet  # Generate keys + vault for a new validator
make deploy                      # Full deployment pipeline
make snapshot                    # Download and apply snapshot for fast sync
make execution                   # Setup execution layer (statesync socket)
make register                    # Register as validator (requires synced node + 100k MON)
make rpc                         # Setup JSON-RPC server
make fastlane                    # Deploy FastLane MEV sidecar (rootless docker)
make upgrade CONFIRM=yes         # Upgrade monad packages to latest version
make observability               # Deploy observability stack (Prometheus + Grafana)
make migrate OLD=v1 NEW=v2       # Fast-migrate validator to a new host
```

### Monitoring

```bash
make health                      # Run health checks
make status                      # Validator dashboard (sync, voting, stake, MEV)
make sidecar-health              # Check FastLane sidecar /health endpoint
make panic-check                 # Scan recent consensus journals for panic patterns
make logs                        # Tail logs (SVC=consensus|execution|rpc LINES=50)
make watch                       # Stream logs with color (SVC=consensus|execution|rpc)
make grafana                     # Open Grafana via SSH tunnel
```

### Operations

```bash
make restart                     # Restart execution → consensus → rpc
make stop CONFIRM=yes            # Stop all monad services
make start                       # Start execution → consensus → rpc
make backup-config               # Backup node config on remote server
make backup-keys                 # Download validator keystores to secrets/
make commission RATE=20          # Set commission rate
make claim                       # Claim validator rewards
make compound                    # Claim + restake rewards
make auto-compound               # Enable nightly auto-compound timer
```

### Recovery

```bash
make recovery            # Run full recovery playbook
make diagnose            # Show diagnostic info (disk, memory, services)
```

### Utilities

```bash
make ping                # Test SSH connectivity
make hardware            # Show server hardware specs (CPU, RAM, storage)
make speedtest           # Run bandwidth speedtest
make ssh                 # SSH into first validator
make check               # Syntax check all playbooks
```

### Vault

```bash
make vault-edit          # Edit vault secrets (decrypt → edit → re-encrypt)
make vault-encrypt       # Encrypt vault file
make vault-decrypt       # Decrypt vault file
```

## Snapshot Sync

New nodes should sync from a snapshot rather than from genesis:

```bash
make deploy              # Deploy node first
make snapshot            # Download and apply latest snapshot
make status              # Monitor block height
```

The snapshot is downloaded from Monad's official CDN. Depending on your bandwidth, this can take 30–60 minutes. After applying, the node will catch up the remaining blocks automatically.

## Validator Registration

After your node is fully synced:

```bash
make register
```

**Requirements:**
- Node must be synced (`eth_syncing` returns `false`)
- Wallet funded with **100,000+ MON** for self-stake
- `register_validator: true` set in inventory
- Vault configured with `vault_funded_wallet_private_key` and addresses

The registration script stakes MON, submits your validator keys on-chain, and begins participating in consensus once the stake activates.

## Network Ports

**Validator:**

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 8000 | TCP/UDP | Public | P2P consensus |
| 8001 | UDP | Public | Auth |
| 8002 | TCP | Localhost only | JSON-RPC |

**Fullnode:**

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 8010 | TCP/UDP | Public | P2P consensus |
| 8011 | UDP | Public | Auth |
| 8090 | TCP | Localhost only | JSON-RPC |

**Observability (opt-in):**

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 3000 | TCP | Public | Grafana dashboard |
| 9090 | TCP | Localhost only | Prometheus (Docker internal) |
| 4317 | TCP | Localhost only | OTEL gRPC (Docker internal) |

**FastLane MEV sidecar (opt-in):**

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 8765 | TCP | Localhost only | Sidecar `/health` + monitoring (rootless Docker) |

Only P2P and auth ports are exposed publicly. RPC, sidecar, and internal services are bound to localhost. Grafana (3000) is exposed through the firewall when the observability stack is deployed.

## Observability

An optional monitoring stack that runs alongside the validator node:

```bash
make observability       # Deploy the stack
make grafana             # Open Grafana via SSH tunnel
```

**What's included:**
- **Grafana** dashboard with validator health, staking, MEV, consensus stats, system resources
- **Prometheus** scraping `node_exporter` and custom monad metrics (textfile collector)
- **OTEL Collector** forwarding telemetry to Monad infra
- **Custom monad exporter** that queries the RPC, staking contract, and the FastLane sidecar every 30s

**Metrics exported:**
- Block height, sync status, epoch, version-outdated flag
- Validator stake, pending stake, unclaimed rewards, commission, wallet balance
- Consensus round, voting rate, skipped rounds, network participation, proposals
- Consensus panic-pattern count and `NRestarts` (restart-loop detection)
- MEV sidecar tx counter (`monad_mev_tx_received`) and last-tx timestamp (`monad_mev_last_received_timestamp`)

**Bundled Grafana alert rules:**

| Rule | Fires when |
|---|---|
| `ServiceDown` | Consensus or execution unit not active for 1m |
| `NodeOutOfSync` | `eth_syncing` non-false for 5m |
| `VotingRateLow` | Vote success drops below 80% over 5m |
| `RoundProgressionStalled` | Consensus round flat for `alert_round_stall_seconds` |
| `ConsensusRestartLoop` | `NRestarts` delta over 10m exceeds threshold |
| `PanicPatternDetected` | "high qc too far / block tree root / panicked" in journal |
| `MevSidecarStale` | FastLane sidecar received no tx in >300s (configurable) |
| `DiskSpaceLow` | Root mount above `alert_disk_threshold` (%) |
| `HighMemoryUsage` | Memory above 90% for 10m |
| `LowWalletBalance` | Auth wallet below 1 MON for 10m |
| `NodeExporterDown` / `OtelCollectorDown` | Scrape targets unreachable |
| `MonadVersionOutdated` | Local monad version differs from latest published |

**Alerting** (optional): Configure `vault_telegram_bot_token` and `vault_telegram_chat_id` in vault for Telegram delivery.

The stack is opt-in: set `observability_enabled: true` in your inventory or run `make observability` as a standalone playbook.

## FastLane MEV Sidecar

Optional MEV sidecar that connects to the consensus mempool socket and forwards transactions to the FastLane network. Runs as a **rootless Docker container** under the `monad` user, managed by a user-level systemd unit.

```bash
make fastlane            # Deploy the sidecar
make sidecar-health      # Probe the /health endpoint
make status              # Sidecar shown as ●; turns yellow if no tx in >5m
```

**Architecture:**

```
monad consensus  ─┐
                  ├──▶  /var/.../mempool.sock  ◀──[ bind-mount, read-only ]──  fastlane-sidecar container
                  │
                  └──  unlink + bind on restart  ──▶  socket inode changes
                                                          │
                                       fastlane-sidecar-watcher.path  ──▶  fastlane-sidecar-watcher.service
                                                          │
                                                          └─▶  systemctl --user restart fastlane-sidecar
```

**Three defense layers against stale-inode silent failures** (the failure mode that caused a 3-day silent MEV outage before this was hardened):
1. `.path` unit watches the **parent directory** for `IN_CREATE` (a watch on the file itself follows the dead inode after unlink)
2. Watcher service waits up to 30s for `[ -S socket ]` before triggering restart
3. `fastlane-sidecar.service` runs `ExecStartPre=[ -S socket ]` on **every** start path — refuses to start if the socket is missing, preventing Docker from auto-creating a host directory at the bind-mount path

The dashboard badge (`make status`) consults `/health` freshness, not just `systemctl is-active` — a sidecar wedged on a phantom inode still reports active but the badge turns yellow.

Enable per host in inventory:

```yaml
my-validator:
  ansible_host: "1.2.3.4"
  fastlane_enabled: true
```

## Troubleshooting

**Node won't start**
```bash
make diagnose                # Check disk, memory, service status
make logs LINES=200          # View recent consensus logs on the server
```

**Sync is stuck or slow**
```bash
make status                  # Check current block height
make logs SVC=consensus LINES=200  # Look for errors in recent logs
make snapshot                # Re-apply snapshot if needed
```

**Connection refused / can't reach node**
```bash
make ping                    # Test SSH connectivity
make hardware                # Verify server specs
# Check firewall: ports 8000 (TCP/UDP) and 8001 (UDP) must be open
```

**TrieDB mount issues**
```bash
make diagnose                # Check disk partitions
# Verify NVMe device path matches triedb_config.drive in all.yml
# Default: /dev/nvme0n1
```

**Recovery from crash**
```bash
make recovery                # Full recovery: check services, repair data, restart
```

**FastLane sidecar shows yellow in `make status` (stale `/health`)**
```bash
make sidecar-health          # Confirm /health is responding but tx_received is stale
# The .path watcher should auto-restart on the next consensus socket recreate.
# If not, force it:
systemctl --user restart fastlane-sidecar.service
```
Cause: the sidecar's bind-mount pinned a now-deleted socket inode. The watcher
is the long-term fix; ExecStartPre guarantees the container won't start with
the socket missing.

## Contributing

Contributions are welcome. Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-change`)
3. Follow [Conventional Commits](https://www.conventionalcommits.org/) for commit messages
4. Submit a pull request

## License

[MIT](LICENSE)
