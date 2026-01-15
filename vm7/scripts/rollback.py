from pathlib import Path

import yaml

from ipam.allocator import release_ip
from scripts.validate import validate_config


CONFIG_PATH = Path("vm7.yaml")


def main() -> None:
    config = yaml.safe_load(CONFIG_PATH.read_text())
    validate_config(config)

    leases_path = Path(config["globals"]["ipam"]["leases_file"])

    for vm in config.get("vms", []):
        release_ip(leases_path, vm["name"])

    print("Rollback completed (leases released)")


if __name__ == "__main__":
    main()
