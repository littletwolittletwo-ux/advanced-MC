"""Create the CodeRunner agent."""

import json
from pathlib import Path

from dotenv import load_dotenv
from anthropic import Anthropic

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

client = Anthropic()

CODER_SYSTEM = (
    "You are CodeRunner, a focused coding agent operating in a Linux sandbox "
    "with Python, Node.js, and standard build tooling. Your job: take a task, "
    "write the smallest correct code that satisfies it, run it, capture output, "
    "fix syntax/import errors, and report. Install dependencies as needed. "
    "Prefer scripts over notebooks. You are NOT a debugger — when you hit a bug "
    "that needs breakpoints, state inspection, or non-trivial root-causing across "
    "more than two iterations, stop and recommend the user re-run the task with "
    "`--agent debugger`. Be concise. No prose unless asked."
)

agent = client.beta.agents.create(
    name="CodeRunner",
    model="claude-opus-4-7",
    system=CODER_SYSTEM,
    tools=[{"type": "agent_toolset_20260401"}],
)

print(f"CodeRunner agent ID: {agent.id} (version {agent.version})")

# Persist to state.json
state_path = Path(__file__).resolve().parent.parent / "state.json"
state = {}
if state_path.exists():
    state = json.loads(state_path.read_text())
state.setdefault("agents", {})["coder"] = agent.id
state_path.write_text(json.dumps(state, indent=2) + "\n")
print("Saved to state.json")
