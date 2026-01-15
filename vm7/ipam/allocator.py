import fcntl
import ipaddress
import json
from pathlib import Path

import yaml


def load_pools(pools_path: Path) -> dict:
    return yaml.safe_load(pools_path.read_text())


def load_leases(leases_path: Path) -> dict:
    if not leases_path.exists():
        return {"leases": {}}
    return json.loads(leases_path.read_text())


def _ip_range(start: str, end: str):
    start_ip = ipaddress.ip_address(start)
    end_ip = ipaddress.ip_address(end)
    current = start_ip
    while current <= end_ip:
        yield str(current)
        current += 1


def allocate_ip(pool: dict, leases: dict) -> str:
    allocated = {entry["ip"] for entry in leases.get("leases", {}).values()}
    for candidate in _ip_range(pool["range_start"], pool["range_end"]):
        if candidate not in allocated:
            return candidate
    raise RuntimeError("No available IPs in pool")


def reserve_ip(leases_path: Path, hostname: str, pool_name: str, ip: str) -> None:
    leases_path.parent.mkdir(parents=True, exist_ok=True)
    with leases_path.open("r+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        content = handle.read() or "{\"leases\": {}}"
        data = json.loads(content)
        leases = data.setdefault("leases", {})
        if hostname in leases:
            return
        leases[hostname] = {"ip": ip, "pool": pool_name}
        handle.seek(0)
        handle.truncate()
        handle.write(json.dumps(data, indent=2, sort_keys=True))
        handle.flush()
        fcntl.flock(handle, fcntl.LOCK_UN)


def release_ip(leases_path: Path, hostname: str) -> None:
    if not leases_path.exists():
        return
    with leases_path.open("r+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        data = json.loads(handle.read())
        leases = data.get("leases", {})
        if hostname in leases:
            leases.pop(hostname)
        handle.seek(0)
        handle.truncate()
        handle.write(json.dumps(data, indent=2, sort_keys=True))
        handle.flush()
        fcntl.flock(handle, fcntl.LOCK_UN)
