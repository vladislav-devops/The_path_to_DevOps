from pathlib import Path
from string import Template


def render_cloud_init(template_path: Path, output_path: Path, context: dict) -> None:
    template = Template(template_path.read_text())
    rendered = template.safe_substitute(context)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
