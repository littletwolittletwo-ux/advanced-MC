"""
codex-bridge: a thin Anthropic-API-shaped HTTP frontend that routes
calls to `codex exec` (using the user's ChatGPT subscription quota).

Used by OpenClaw's Sunny agent only. Other agents continue to hit
api.anthropic.com directly.
"""
import json
import os
import subprocess
import time
import uuid
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
import uvicorn

app = FastAPI()

# Read model flag from /tmp file written by the migration script
MODEL_FLAG_FILE = "/tmp/.codex-model-flag"
try:
    with open(MODEL_FLAG_FILE) as f:
        MODEL_FLAG = f.read().strip()
except Exception:
    MODEL_FLAG = ""

LOG_PATH = os.path.expanduser("~/projects/codex-bridge/bridge.log")


def log(msg: str) -> None:
    with open(LOG_PATH, "a") as f:
        f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")


def messages_to_prompt(messages: list) -> str:
    """Flatten Anthropic-style messages into a single prompt string Codex can consume."""
    out = []
    for m in messages:
        role = m.get("role", "user")
        content = m.get("content", "")
        if isinstance(content, list):
            # Anthropic content blocks — extract text
            text_parts = []
            for block in content:
                if isinstance(block, dict):
                    if block.get("type") == "text":
                        text_parts.append(block.get("text", ""))
                    elif block.get("type") == "tool_use":
                        text_parts.append(f"[TOOL CALL: {block.get('name')} args={json.dumps(block.get('input', {}))}]")
                    elif block.get("type") == "tool_result":
                        text_parts.append(f"[TOOL RESULT: {block.get('content', '')}]")
            content = "\n".join(text_parts)
        out.append(f"{role.upper()}: {content}")
    return "\n\n".join(out)


def call_codex(prompt: str, system: str = "") -> tuple:
    """Invoke `codex exec` with the prompt. Returns (response_text, metadata)."""
    full_prompt = (system + "\n\n" + prompt) if system else prompt

    cmd = ["codex", "exec", "--skip-git-repo-check"]
    if MODEL_FLAG:
        cmd.extend(MODEL_FLAG.split())
    cmd.append(full_prompt)

    start = time.time()
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=180,
        )
    except subprocess.TimeoutExpired:
        log(f"Codex timeout after 180s for prompt: {prompt[:200]}")
        raise HTTPException(status_code=504, detail="codex exec timeout")

    elapsed = time.time() - start

    if result.returncode != 0:
        log(f"Codex non-zero exit: returncode={result.returncode} stderr={result.stderr[:500]}")
        raise HTTPException(status_code=502, detail=f"codex exec failed: {result.stderr[:500]}")

    response_text = result.stdout.strip()
    metadata = {
        "elapsed_seconds": elapsed,
        "stderr_excerpt": result.stderr[-500:] if result.stderr else "",
    }
    return response_text, metadata


@app.get("/")
def root():
    return {"service": "codex-bridge", "status": "alive"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/v1/messages")
async def messages(req: Request):
    """Anthropic-API-shaped endpoint. Translates to codex exec."""
    body = await req.json()
    log(f"Incoming /v1/messages: model={body.get('model')} msgs={len(body.get('messages', []))}")

    msgs = body.get("messages", [])
    system = body.get("system", "")
    if isinstance(system, list):
        system = "\n".join(b.get("text", "") for b in system if isinstance(b, dict))

    prompt = messages_to_prompt(msgs)

    try:
        response_text, meta = call_codex(prompt, system)
    except HTTPException as e:
        return JSONResponse(
            status_code=e.status_code,
            content={
                "type": "error",
                "error": {"type": "api_error", "message": e.detail},
            },
        )

    log(f"Codex response in {meta['elapsed_seconds']:.2f}s: {response_text[:200]}")

    # Build Anthropic-shaped response
    msg_id = f"msg_{uuid.uuid4().hex[:24]}"
    return {
        "id": msg_id,
        "type": "message",
        "role": "assistant",
        "model": body.get("model", "claude-via-codex"),
        "content": [{"type": "text", "text": response_text}],
        "stop_reason": "end_turn",
        "stop_sequence": None,
        "usage": {
            "input_tokens": 0,
            "output_tokens": 0,
        },
    }


if __name__ == "__main__":
    log("codex-bridge starting on port 18790")
    uvicorn.run(app, host="127.0.0.1", port=18790, log_level="info")
