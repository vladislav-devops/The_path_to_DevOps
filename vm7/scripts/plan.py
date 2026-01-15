import json
from pathlib import Path

import yaml

from ipam.allocator import allocate_ip, load_leases, load_pools
from scripts.validate import validate_config


CONFIG_PATH = Path("vm7.yaml")
OUTPUT_PATH = Path("plan.json")


def build_plan(config: dict, pools: dict, leases: dict) -> dict:
    networks = {network["name"]: network["pool"] for network in config.get("networks", [])}
    planned = []

    for vm in config.get("vms", []):
        hostname = vm["name"]
        pool_name = networks[vm["network"]]
        pool = pools["pools"][pool_name]
        current_lease = leases.get("leases", {}).get(hostname)
        if current_lease:
            ip = current_lease["ip"]
            action = "reuse"
        else:
            ip = allocate_ip(pool, leases)
            action = "reserve"
        planned.append(
            {
                "name": hostname,
                "pool": pool_name,
                "ip": ip,
                "action": action,
                "type": vm["type"],
                "template_id": vm["template_id"],
            }
        )

    return {"vms": planned}


def main() -> None:
    config = yaml.safe_load(CONFIG_PATH.read_text())
    validate_config(config)

    pools_path = Path(config["globals"]["ipam"]["pools_file"])
    leases_path = Path(config["globals"]["ipam"]["leases_file"])

    pools = load_pools(pools_path)
    leases = load_leases(leases_path)
    plan = build_plan(config, pools, leases)

    OUTPUT_PATH.write_text(json.dumps(plan, indent=2))
    print(f"Plan written to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
