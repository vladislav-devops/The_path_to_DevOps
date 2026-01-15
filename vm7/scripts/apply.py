import json
from pathlib import Path

import yaml

from access.render import render_cloud_init
from ipam.allocator import allocate_ip, load_leases, load_pools, reserve_ip
from proxmox.client import ProxmoxClient, ProxmoxConfig
from proxmox.provision import ProvisionRequest, provision_vm
from scripts.validate import validate_config


CONFIG_PATH = Path("vm7.yaml")
OUTPUT_DIR = Path("artifacts")


def main() -> None:
    config = yaml.safe_load(CONFIG_PATH.read_text())
    validate_config(config)

    globals_block = config["globals"]
    pools_path = Path(globals_block["ipam"]["pools_file"])
    leases_path = Path(globals_block["ipam"]["leases_file"])

    pools = load_pools(pools_path)
    leases = load_leases(leases_path)

    networks = {network["name"]: network["pool"] for network in config.get("networks", [])}

    proxmox_config = ProxmoxConfig(**globals_block["proxmox"])
    client = ProxmoxClient(proxmox_config)

    access_config = globals_block["access"]

    for vm in config.get("vms", []):
        hostname = vm["name"]
        pool_name = networks[vm["network"]]
        pool = pools["pools"][pool_name]
        lease = leases.get("leases", {}).get(hostname)

        if lease:
            ip = lease["ip"]
        else:
            ip = allocate_ip(pool, leases)
            reserve_ip(leases_path, hostname, pool_name, ip)
            leases = load_leases(leases_path)

        cloud_init_context = {
            "hostname": hostname,
            "username": access_config["user"],
            "ssh_public_key": access_config["ssh_public_key"],
            "ssh_password_auth": str(access_config.get("ssh_password_auth", False)).lower(),
            "password": access_config.get("temp_password") or "",
            "ip": ip,
            "netmask": pool["cidr"].split("/")[-1],
            "gateway": pool["gateway"],
            "dns": json.dumps(pool["dns"]),
        }

        output_path = OUTPUT_DIR / f"{hostname}-cloud-init.yaml"
        render_cloud_init(Path("access/cloud-init.tftpl"), output_path, cloud_init_context)

        request = ProvisionRequest(
            name=hostname,
            template_id=vm["template_id"],
            cpu=vm["cpu"],
            ram_mb=vm["ram_mb"],
            disk_gb=vm["disk_gb"],
            cloud_init_path=output_path,
        )

        try:
            vm_id = provision_vm(client, request)
            print(f"Provisioned {hostname} as VM ID {vm_id}")
        except NotImplementedError:
            print(f"Dry-run: provision {hostname} with IP {ip}")


if __name__ == "__main__":
    main()
