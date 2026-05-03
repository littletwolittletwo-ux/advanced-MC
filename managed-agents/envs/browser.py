"""Create the browser-env environment with agent-browser + patchright pre-installed."""

import json
import sys
from pathlib import Path

from dotenv import load_dotenv
from anthropic import Anthropic

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

client = Anthropic()

environment = client.beta.environments.create(
    name="browser-env",
    config={
        "type": "cloud",
        "packages": {
            "npm": ["agent-browser"],
            "pip": ["patchright"],
        },
        "networking": {"type": "unrestricted"},
    },
)

print(f"browser-env ID: {environment.id}")

# Persist to state.json
state_path = Path(__file__).resolve().parent.parent / "state.json"
state = {}
if state_path.exists():
    state = json.loads(state_path.read_text())
state.setdefault("environments", {})["browser"] = environment.id
state_path.write_text(json.dumps(state, indent=2) + "\n")
print("Saved to state.json")
