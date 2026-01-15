# vm7 — Infrastructure Bootstrap for Proxmox

vm7 is a **bootstrap layer** for Proxmox that focuses only on:
- provisioning VM/LXC resources,
- lightweight IP allocation (IPAM-lite),
- standardized initial access (SSH + user),
- generating inventory for downstream automation.

It **does not** install or manage services, monitoring, logging, or application configuration.

## Scope

**vm7 is responsible for**:
- Creating VM/LXC from templates
- Allocating IPs from declared pools
- Rendering cloud-init for first access
- Writing inventory output

**vm7 is not responsible for**:
- Service installation (Grafana, ELK, etc.)
- Post-bootstrap configuration
- Monitoring/logging stacks
- Application logic

## Quick Start

```bash
cd vm7

# 1) Validate config
just validate

# 2) Plan allocation + provisioning
just plan

# 3) Apply provisioning
just apply

# 4) Render inventory
just inventory
```

## Repository Layout

```
vm7/
├── vm7.yaml               # Source of truth
├── justfile               # Orchestration (plan/apply/rollback)
├── ipam/
│   ├── pools.yaml          # Declared IP pools
│   ├── leases.json         # Allocation state
│   └── allocator.py        # IPAM-lite allocator
├── proxmox/
│   ├── client.py           # Proxmox API wrapper (minimal)
│   └── provision.py        # VM/LXC provisioning workflow
├── access/
│   ├── cloud-init.tftpl    # Bootstrap-only cloud-init
│   └── render.py           # Cloud-init renderer
├── inventory/
│   └── render.py           # Inventory generator
└── scripts/
    ├── validate.py         # vm7.yaml validation
    ├── plan.py             # Plan (dry-run)
    ├── apply.py            # Apply provisioning
    └── rollback.py         # Rollback (cleanup leases)
```

## vm7.yaml Format

```yaml
version: 1

globals:
  proxmox:
    endpoint: "https://pve.local:8006"
    username: "root@pam"
    token_name: "vm7"
    token_secret: "..."
    node: "pve01"
    datastore: "local-lvm"

  access:
    user: "devops"
    ssh_public_key: "ssh-ed25519 AAAA..."
    ssh_password_auth: false
    temp_password: null

  ipam:
    pools_file: "ipam/pools.yaml"
    leases_file: "ipam/leases.json"

networks:
  - name: mgmt
    pool: "mgmt"
  - name: services
    pool: "services"

vms:
  - name: "web-01"
    type: "vm"
    network: "mgmt"
    cpu: 2
    ram_mb: 4096
    disk_gb: 40
    template_id: 9000
    tags: ["bootstrap", "web"]
    env: "prod"
```

**Notes:**
- IP addresses are never specified manually.
- `network` maps to a declared IP pool.
- `template_id` references a Proxmox template.

## IPAM-lite Rules

- The **leases file is the source of truth**.
- IPs are reserved **before** provisioning.
- First available IP in range is allocated.
- Network scanning is validation-only (optional, not a source of truth).

## Plan / Apply / Rollback

- **Plan**: compute allocations and intended changes, no state changes.
- **Apply**: lock leases, reserve IPs, render cloud-init, call Proxmox provisioning, write inventory.
- **Rollback**: release leases for failed operations.

## Dependencies

- Python 3.10+
- `PyYAML` for YAML parsing

