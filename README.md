# Monad Validator

Ansible automation for deploying and managing Monad validators on testnet.

## Requirements

| Component | Specification |
|-----------|---------------|
| OS | Ubuntu 22.04 / 24.04 |
| CPU | 16+ cores |
| RAM | 32GB minimum |
| Storage | 2TB NVMe (TrieDB) + 500GB (OS/consensus) |
| Network | 1Gbps, static IP |

## Quick Start

```bash
# 1. Install dependencies
ansible-galaxy install -r requirements.yml

# 2. Configure
cp group_vars/vault.yml.example group_vars/vault.yml
vim group_vars/vault.yml
vim inventory/hosts.yml

# 3. Encrypt secrets
ansible-vault encrypt group_vars/vault.yml

# 4. Deploy
make deploy
```

## Configuration

### Vault Secrets (`group_vars/vault.yml`)

```yaml
vault_validator_01_ip: "1.2.3.4"

# Keys (generate fresh for production)
vault_secp_private_key: "64_hex_chars_no_0x_prefix"
vault_bls_private_key: "0x_66_chars_with_prefix"

# Staking
vault_funded_wallet_private_key: "wallet_with_100k_MON"
vault_beneficiary_address: "0x..."
vault_auth_address: "0x..."
```

### Inventory (`inventory/hosts.yml`)

```yaml
validators:
  hosts:
    my-validator:
      ansible_host: "{{ vault_validator_01_ip }}"
      setup_triedb: true
      triedb_config:
        drive: "/dev/nvme0n1"  # verify: lsblk
```

## Commands

```bash
make deploy      # Full deployment
make register    # Register validator (requires synced node + 100k MON)
make upgrade     # Upgrade monad binary
make health      # Run health checks
make status      # Show node status
make sync        # Check sync progress
make restart     # Restart node
make backup      # Backup config and keys
make recovery    # Recovery procedures
make diagnose    # Diagnostic info
make ping        # Test connectivity
```

## Project Structure

```
├── inventory/hosts.yml       # Server inventory
├── group_vars/
│   ├── all.yml               # Main configuration
│   └── vault.yml             # Secrets (encrypted)
├── playbooks/
│   ├── deploy-validator.yml  # Full deployment
│   ├── register-validator.yml
│   ├── upgrade-node.yml
│   ├── maintenance.yml       # Health, status, sync, restart, backup
│   └── recovery.yml
└── roles/
    ├── common/               # Preflight checks
    ├── prepare_server/       # Packages, sysctl, hugepages, triedb
    ├── monad-node/           # Binary, config, systemd service
    ├── validator/            # Staking CLI, registration
    ├── monitoring/           # Health checks, alerts
    └── backup/               # Backup scripts
```

## Validator Registration

After node is fully synced:

```bash
make register
```

Requirements:
- Node synced (`eth_syncing` returns `false`)
- SECP private key (64 hex chars, no 0x)
- BLS private key (66 chars with 0x)
- Funded wallet with 100,000+ MON

## Network

| Port | Protocol | Purpose |
|------|----------|---------|
| 8000 | TCP/UDP | P2P |
| 8001 | UDP | Auth |
| 8002 | TCP | RPC (localhost only) |

## Useful Commands

```bash
# Check sync status
curl -s localhost:8002 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","id":1}' | jq

# View logs
journalctl -u monad-consensus -f

# Service status
systemctl status monad-consensus
```

## License

MIT
