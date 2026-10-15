"""Print documented Studio MCP input tool schemas for Play-mode testing."""

import json
import sys

sys.path.insert(0, "/private/tmp")
from chest_rng_studio_sync_20261014 import Client


def main():
    client = Client()
    try:
        tools = client.request("tools/list", {})["tools"]
        print("TOOL_NAMES", [tool["name"] for tool in tools])
        for tool in tools:
            if "mouse" in tool["name"] or "keyboard" in tool["name"]:
                print(json.dumps(tool, indent=2))
    finally:
        client.close()


if __name__ == "__main__":
    main()
