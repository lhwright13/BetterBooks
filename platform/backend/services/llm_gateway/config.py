import json
import os
from pathlib import Path

_parents = Path(__file__).resolve().parents
DEFAULT_ROOT_PATH = (_parents[2] if len(_parents) > 2 else _parents[-1]) / "llm_config.json"
DEFAULT_LOCAL_PATH = Path(__file__).with_name("config.json")


def load_config(path: str | Path | None = None) -> dict:
    env_path = os.getenv("AZURE_OPENAI_CONFIG")
    if path:
        cfg_path = Path(path)
    elif env_path:
        cfg_path = Path(env_path)
    else:
        cfg_path = DEFAULT_ROOT_PATH if DEFAULT_ROOT_PATH.exists() else DEFAULT_LOCAL_PATH

    data: dict = {}
    if cfg_path.exists():
        with open(cfg_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)

    data.setdefault("model", "gpt-4o-mini")
    data.setdefault("generation_config", {"temperature": 0.7, "max_tokens": 4000})
    data.setdefault("prompt_options", {})
    data.setdefault("base_preprompt", "")

    azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
    azure_api_key = os.getenv("AZURE_OPENAI_API_KEY")
    azure_deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME")
    azure_api_version = os.getenv("AZURE_OPENAI_API_VERSION", "2024-12-01-preview")

    if azure_endpoint:
        data["azure_endpoint"] = azure_endpoint
    if azure_api_key:
        data["api_key"] = azure_api_key
    if azure_deployment:
        data["deployment_name"] = azure_deployment
    if azure_api_version:
        data["api_version"] = azure_api_version

    data.setdefault("azure_endpoint", "https://your-resource.openai.azure.com/")
    data.setdefault("deployment_name", "gpt-4o-mini")
    data.setdefault("api_version", "2024-12-01-preview")
    data.setdefault("api_key", "test-key")

    return data
