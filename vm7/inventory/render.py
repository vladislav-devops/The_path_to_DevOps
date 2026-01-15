import json
from pathlib import Path

import yaml


def load_config(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def render_inventory(config_path: Path, inventory_path: Path, leases_path: Path) -> None:
    config = load_config(config_path)
    leases = json.loads(leases_path.read_text()).get("leases", {})
    access = config["globals"]["access"]

    inventory = []
    for vm in config.get("vms", []):
        hostname = vm["name"]
        lease = leases.get(hostname)
        if not lease:
            continue
        inventory.append(
            {
                "hostname": hostname,
                "ip": lease["ip"],
                "user": access["user"],
                "network": lease["pool"],
                "environment": vm.get("env"),
            }
        )

    inventory_path.parent.mkdir(parents=True, exist_ok=True)
    inventory_path.write_text(yaml.safe_dump(inventory, sort_keys=False))


if __name__ == "__main__":
    render_inventory(
        Path("vm7.yaml"),
        Path("inventory/inventory.yaml"),
        Path("ipam/leases.json"),
    )
