"""Create the general-env environment (lightweight, no packages)."""

import json
import sys
from pathlib import Path

from dotenv import load_dotenv
from anthropic import Anthropic

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

client = Anthropic()

environment = client.beta.environments.create(
    name="general-env",
    config={
        "type": "cloud",
        "networking": {"type": "unrestricted"},
    },
)

print(f"general-env ID: {environment.id}")

# Persist to state.json
state_path = Path(__file__).resolve().parent.parent / "state.json"
state = {}
if state_path.exists():
    state = json.loads(state_path.read_text())
state.setdefault("environments", {})["general"] = environment.id
state_path.write_text(json.dumps(state, indent=2) + "\n")
print("Saved to state.json")
