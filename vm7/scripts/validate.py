from pathlib import Path

import yaml

REQUIRED_GLOBALS = ["proxmox", "access", "ipam"]
REQUIRED_VM_FIELDS = ["name", "type", "network", "cpu", "ram_mb", "disk_gb", "template_id"]


def validate_config(config: dict) -> None:
    globals_block = config.get("globals", {})
    for key in REQUIRED_GLOBALS:
        if key not in globals_block:
            raise ValueError(f"Missing globals.{key}")

    for network in config.get("networks", []):
        if "name" not in network or "pool" not in network:
            raise ValueError("Each network must define name and pool")

    if not config.get("vms"):
        raise ValueError("No VMs defined")

    for vm in config["vms"]:
        for field in REQUIRED_VM_FIELDS:
            if field not in vm:
                raise ValueError(f"VM {vm.get('name', '<unknown>')} missing field: {field}")

    access = globals_block.get("access", {})
    if not access.get("ssh_public_key"):
        raise ValueError("globals.access.ssh_public_key is required")


def main(config_path: Path) -> None:
    config = yaml.safe_load(config_path.read_text())
    validate_config(config)
    print("vm7.yaml validation passed")


if __name__ == "__main__":
    main(Path("vm7.yaml"))
