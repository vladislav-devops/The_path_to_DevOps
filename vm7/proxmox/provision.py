from dataclasses import dataclass
from pathlib import Path

from proxmox.client import ProxmoxClient


@dataclass
class ProvisionRequest:
    name: str
    template_id: int
    cpu: int
    ram_mb: int
    disk_gb: int
    cloud_init_path: Path
    vm_id: int | None = None


def provision_vm(client: ProxmoxClient, request: ProvisionRequest) -> int:
    vm_id = client.clone_vm(request.template_id, request.name, request.vm_id)
    client.configure_vm(vm_id, request.cpu, request.ram_mb, request.disk_gb)
    client.set_cloud_init(vm_id, str(request.cloud_init_path))
    client.start_vm(vm_id)
    return vm_id
