#!/usr/bin/env python3
"""Runner for Claude Managed Agents — CodeRunner, DevDebugger, WebOps.

Usage:
  python run.py --agent coder    "write a quicksort and benchmark it"
  python run.py --agent debugger "fix segfault.py"
  python run.py --agent browser  "open https://example.com and screenshot it"
  python run.py --continue <session_id> "follow-up message"
"""

import argparse
import json
import sys
from pathlib import Path

import httpx
from dotenv import load_dotenv
from rich.console import Console
from rich.text import Text
from anthropic import Anthropic

# Load .env from project root
PROJECT_ROOT = Path(__file__).resolve().parent
load_dotenv(PROJECT_ROOT / ".env")

console = Console()

AGENT_ENV_MAP = {
    "coder": "general",
    "debugger": "general",
    "browser": "browser",
}

# Inlined bootstrap — the sandbox doesn't mount local files at /workspace/
BOOTSTRAP_MESSAGE = """\
Run the following commands to bootstrap the browser environment. \
Confirm each succeeds with exit code 0, then reply "Bootstrap complete." \
and wait for my real task.

```bash
set -euo pipefail
if [ -f /tmp/.browser_env_ready ]; then echo "[bootstrap] ready"; exit 0; fi
echo "[bootstrap] installing Chrome for Testing..."
agent-browser install
echo "[bootstrap] installing Chromium for Patchright..."
python3 -m patchright install chromium
mkdir -p /root/.patchright-profiles
agent-browser doctor --quick
touch /tmp/.browser_env_ready
echo "[bootstrap] done"
```
"""


def load_state() -> dict:
    state_path = PROJECT_ROOT / "state.json"
    if not state_path.exists():
        console.print("[red]state.json not found. Run envs/*.py and agents/*.py first.[/red]")
        sys.exit(1)
    return json.loads(state_path.read_text())


def ensure_log_dir() -> Path:
    log_dir = PROJECT_ROOT / "logs"
    log_dir.mkdir(exist_ok=True)
    return log_dir


def handle_custom_tool_use(client: Anthropic, session_id: str, event) -> None:
    """Handle custom tool calls (e.g. trace_python)."""
    tool_name = event.name
    tool_use_id = event.id

    if tool_name == "trace_python":
        result_text = (
            "trace_python is an in-sandbox tool. Write the helper script to "
            "~/.tools/trace_python.py if it doesn't exist, then invoke it via bash:\n"
            "  python3 ~/.tools/trace_python.py --script <path> "
            "[--breakpoints N M] [--timeout 60]\n"
            "Use the input parameters provided in this tool call."
        )
    else:
        result_text = f"Unknown custom tool: {tool_name}"

    client.beta.sessions.events.send(
        session_id,
        events=[
            {
                "type": "user.custom_tool_result",
                "tool_use_id": tool_use_id,
                "content": [{"type": "text", "text": result_text}],
            }
        ],
    )


def send_and_stream(client: Anthropic, session_id: str, task: str, log_path: Path) -> None:
    """Send a user message then stream events until idle/terminated."""
    # Send the user message first
    client.beta.sessions.events.send(
        session_id,
        events=[
            {
                "type": "user.message",
                "content": [{"type": "text", "text": task}],
            }
        ],
    )

    # Then open the SSE stream and process events
    with open(log_path, "a") as log_file:
        with client.beta.sessions.events.stream(session_id) as stream:
            for event in stream:
                # Log every event
                try:
                    event_data = event.model_dump() if hasattr(event, "model_dump") else {"type": str(event.type)}
                except Exception:
                    event_data = {"type": str(event.type)}
                log_file.write(json.dumps(event_data, default=str) + "\n")
                log_file.flush()

                etype = event.type

                if etype == "agent.message":
                    for block in event.content:
                        if hasattr(block, "text"):
                            console.print(Text(block.text, style="green"), end="")
                    console.print()

                elif etype == "agent.thinking":
                    if hasattr(event, "content"):
                        for block in event.content:
                            if hasattr(block, "text"):
                                console.print(
                                    Text(f"[thinking] {block.text[:200]}...", style="dim yellow")
                                )

                elif etype == "agent.tool_use":
                    name = getattr(event, "name", "?")
                    args_preview = ""
                    if hasattr(event, "input"):
                        args_str = json.dumps(event.input, default=str)
                        args_preview = args_str[:200]
                    console.print(
                        Text(f"[tool: {name} {args_preview}]", style="dim cyan")
                    )

                elif etype == "agent.tool_result":
                    content_preview = ""
                    if hasattr(event, "content"):
                        for block in event.content:
                            if hasattr(block, "text"):
                                content_preview += block.text
                    if content_preview:
                        console.print(
                            Text(content_preview[:500], style="dim white")
                        )

                elif etype == "agent.custom_tool_use":
                    name = getattr(event, "name", "?")
                    console.print(
                        Text(f"[custom tool: {name}]", style="dim magenta")
                    )
                    handle_custom_tool_use(client, session_id, event)

                elif etype == "session.status_idle":
                    stop_reason = getattr(event, "stop_reason", "unknown")
                    console.print(
                        f"\n[bold green]Session idle[/bold green] (stop_reason: {stop_reason})"
                    )
                    break

                elif etype == "session.status_terminated":
                    error_info = getattr(event, "error", None)
                    console.print(
                        f"\n[bold red]Session terminated[/bold red]: {error_info}"
                    )
                    sys.exit(1)

                elif etype == "session.error":
                    error_obj = getattr(event, "error", None)
                    console.print(
                        Text(f"[error] {error_obj}", style="bold red")
                    )
                    sys.exit(1)

                elif etype == "span.model_request_end":
                    if hasattr(event, "model_usage"):
                        usage = event.model_usage
                        if usage:
                            input_t = getattr(usage, "input_tokens", "?")
                            output_t = getattr(usage, "output_tokens", "?")
                            console.print(
                                Text(f"[tokens: in={input_t} out={output_t}]", style="dim")
                            )


def main():
    parser = argparse.ArgumentParser(description="Run Claude Managed Agents")
    parser.add_argument(
        "--agent",
        choices=["coder", "debugger", "browser"],
        help="Which agent to run",
    )
    parser.add_argument(
        "--continue",
        dest="continue_session",
        metavar="SESSION_ID",
        help="Resume an existing session",
    )
    parser.add_argument("task", nargs="?", help="The task to send to the agent")
    args = parser.parse_args()

    if not args.task:
        parser.error("A task message is required")

    # Long read timeout for SSE streams (agents can run for minutes)
    client = Anthropic(
        timeout=httpx.Timeout(connect=30.0, read=600.0, write=30.0, pool=30.0)
    )
    state = load_state()
    log_dir = ensure_log_dir()

    if args.continue_session:
        session_id = args.continue_session
        console.print(f"[bold]Resuming session:[/bold] {session_id}")
        log_path = log_dir / f"{session_id}.jsonl"
        send_and_stream(client, session_id, args.task, log_path)
        return

    if not args.agent:
        parser.error("--agent is required when not using --continue")

    # Resolve IDs from state
    agent_id = state.get("agents", {}).get(args.agent)
    env_key = AGENT_ENV_MAP[args.agent]
    env_id = state.get("environments", {}).get(env_key)

    if not agent_id:
        console.print(f"[red]Agent '{args.agent}' not found in state.json[/red]")
        sys.exit(1)
    if not env_id:
        console.print(f"[red]Environment '{env_key}' not found in state.json[/red]")
        sys.exit(1)

    console.print(f"[bold]Agent:[/bold] {args.agent} ({agent_id})")
    console.print(f"[bold]Environment:[/bold] {env_key} ({env_id})")

    # Create session
    session = client.beta.sessions.create(
        agent=agent_id,
        environment_id=env_id,
        title=args.task[:60],
    )
    session_id = session.id
    console.print(f"[bold]Session:[/bold] {session_id}\n")

    log_path = log_dir / f"{session_id}.jsonl"

    # For browser sessions, bootstrap first
    if args.agent == "browser":
        console.print("[yellow]Running browser bootstrap...[/yellow]")
        send_and_stream(client, session_id, BOOTSTRAP_MESSAGE, log_path)
        console.print("[yellow]Bootstrap done. Sending real task...[/yellow]\n")

    # Send the actual task
    send_and_stream(client, session_id, args.task, log_path)

    # Print summary
    console.print(f"\n[bold]Session ID:[/bold] {session_id}")
    console.print(f"[bold]Log:[/bold] {log_path}")
    console.print(
        f"[dim]Resume with: python run.py --continue {session_id} \"follow-up message\"[/dim]"
    )


if __name__ == "__main__":
    main()
