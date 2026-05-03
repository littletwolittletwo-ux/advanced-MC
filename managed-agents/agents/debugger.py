"""Create the DevDebugger agent.

The trace_python custom tool is defined here so the agent has a clean schema.
At runtime, the agent writes a helper script (~/.tools/trace_python.py) into
the sandbox on first use and invokes it via bash. The custom tool definition
tells the model what's available; run.py does NOT need client-side dispatch
for this tool — the agent handles it entirely inside the sandbox.
"""

import json
from pathlib import Path

from dotenv import load_dotenv
from anthropic import Anthropic

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

client = Anthropic()

DEBUGGER_SYSTEM = (
    "You are DevDebugger, a specialist for diagnosing failing code. "
    "Workflow: (1) reproduce the failure with the smallest possible command, "
    "(2) read the traceback carefully and form a hypothesis, "
    "(3) instrument with print/logging or use trace_python with breakpoints "
    "to verify the hypothesis, (4) state the root cause in one sentence, "
    "(5) propose the minimal diff that fixes it, (6) apply and re-run to confirm. "
    "Show your reasoning at each step. Never silently swallow exceptions. "
    "Never \"fix\" by broadening try/except — find the actual cause. "
    "If after three hypotheses you're still stuck, summarize what you've "
    "ruled out and ask the user for direction.\n\n"
    "trace_python helper: On first use, write the following helper to "
    "~/.tools/trace_python.py and invoke it via bash. It uses sys.settrace "
    "to capture locals at specified breakpoint lines and prints structured "
    "JSON output with exit_code, stdout, stderr, traceback, frame_locals, "
    "and executed_lines. Example: "
    "`python3 ~/.tools/trace_python.py --script /path/to/script.py "
    "--breakpoints 10 25 --timeout 60`"
)

agent = client.beta.agents.create(
    name="DevDebugger",
    model="claude-opus-4-7",
    system=DEBUGGER_SYSTEM,
    tools=[
        {"type": "agent_toolset_20260401"},
        {
            "type": "custom",
            "name": "trace_python",
            "description": (
                "Run a Python script under heavy instrumentation and return a "
                "structured trace. Use when standard exception output is insufficient "
                "— you need locals at frame N, conditional breakpoints, or a coverage "
                "map of which lines actually ran. Pass the absolute path to the script, "
                "optional CLI args, and optional breakpoint line numbers. Returns: "
                "{exit_code, stdout, stderr, traceback (if any), frame_locals at each "
                "breakpoint, executed_lines}. Do NOT use for ordinary script runs — "
                "bash is fine for those. Implementation: the agent writes a helper to "
                "~/.tools/trace_python.py on first use and invokes it via bash."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "script_path": {"type": "string"},
                    "args": {"type": "array", "items": {"type": "string"}},
                    "breakpoint_lines": {"type": "array", "items": {"type": "integer"}},
                    "timeout_seconds": {"type": "integer", "default": 60},
                },
                "required": ["script_path"],
            },
        },
    ],
)

print(f"DevDebugger agent ID: {agent.id} (version {agent.version})")

# Persist to state.json
state_path = Path(__file__).resolve().parent.parent / "state.json"
state = {}
if state_path.exists():
    state = json.loads(state_path.read_text())
state.setdefault("agents", {})["debugger"] = agent.id
state_path.write_text(json.dumps(state, indent=2) + "\n")
print("Saved to state.json")
