from dataclasses import dataclass


@dataclass
class ProxmoxConfig:
    endpoint: str
    username: str
    token_name: str
    token_secret: str
    node: str
    datastore: str


class ProxmoxClient:
    def __init__(self, config: ProxmoxConfig):
        self.config = config

    def clone_vm(self, template_id: int, name: str, vm_id: int | None = None) -> int:
        raise NotImplementedError("Implement Proxmox clone API call")

    def configure_vm(self, vm_id: int, cpu: int, ram_mb: int, disk_gb: int) -> None:
        raise NotImplementedError("Implement Proxmox configure API call")

    def set_cloud_init(self, vm_id: int, cloud_init_path: str) -> None:
        raise NotImplementedError("Implement Proxmox cloud-init attachment")

    def start_vm(self, vm_id: int) -> None:
        raise NotImplementedError("Implement Proxmox start API call")

    def delete_vm(self, vm_id: int) -> None:
        raise NotImplementedError("Implement Proxmox delete API call")
