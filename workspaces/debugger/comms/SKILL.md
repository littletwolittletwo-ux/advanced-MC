# Agent Comms — Communication Skill

## Overview

You have access to the **Agent Comms** platform — a messaging system that connects you to other agents. All inter-agent communication goes through this platform.

You communicate by **sending messages to channels** and **polling for messages addressed to you**. Every message you send and receive is logged and visible to your operator.

## Your Configuration

Your agent ID and channel assignments are in `comms-config.json` in your workspace. Before using any comms command, read your config to know your agent ID and which channels you belong to.

- **Never** send messages to channels you are not a member of.
- **Never** impersonate another agent.

## Checking for Messages (PRIORITY — DO THIS FIRST)

At the start of every interaction cycle, check for unread messages **BEFORE** doing anything else.

```bash
bash scripts/comms-poll.sh
```

This returns any unread messages addressed to you, sorted by priority (P0 first).

- If there are unread messages, **process them in priority order** before doing anything else.
- After reading each message, mark it as read:
  ```bash
  bash scripts/comms-read.sh MESSAGE_ID
  ```
- If there are no unread messages, proceed with your normal tasks.

## Sending a Message

To send a message:

```bash
bash scripts/comms-send.sh CHANNEL_ID "Your message here" PRIORITY
```

- **CHANNEL_ID**: the channel to send to (e.g., `dm:boss-worker`)
- **PRIORITY**: `P0` (critical), `P1` (high), `P2` (normal/default), `P3` (low)
- Always set appropriate priority — do not mark everything P0.

Example:
```bash
bash scripts/comms-send.sh dm:boss-worker "Task complete. The report has been generated and stored." P1
```

## Creating a New Task Thread

When starting a new task or delegation, **ALWAYS** prefix your message with `NEW TASK: [brief description]`.

This creates a thread marker that segments the conversation.

Example:
```bash
bash scripts/comms-send.sh dm:ceo-code-agent "NEW TASK: Build automated daily report system

Requirements:
1. Pull data from all active sources
2. Generate summary with key metrics
3. Support email and dashboard output" P1
```

Every new task **MUST** have a `NEW TASK` marker. Do not continue old threads for new work.

## Reading Thread Context

Before responding to a task, read the current thread to understand the full context:

```bash
bash scripts/comms-thread.sh CHANNEL_ID
```

This returns all messages from the latest `NEW TASK` marker to now. Read the entire thread before responding — do not rely on just the latest message.

## Replying to a Specific Message

To reply directly to a message:

```bash
bash scripts/comms-reply.sh MESSAGE_ID "Your reply here" PRIORITY
```

Use this when responding to a specific question or instruction. The reply will be linked to the original message.

## Using @Handles in Group Chats

In group channels, you can target specific agents using @handles.

Include `@agent-id` in your message body:
```bash
bash scripts/comms-send.sh group:advisory-board "@advisor-1 What are the risks of this approach?" P2
```

Only the tagged agent(s) will see the message in their poll.

To tag multiple agents:
```bash
bash scripts/comms-send.sh group:advisory-board "@advisor-1 @advisor-2 Both of you, analyze this from your perspectives" P2
```

To broadcast to everyone in the group (no handle filtering): send without any @mentions.

**IMPORTANT**: In group chats, only respond to messages where you are specifically tagged. Do not respond to messages tagged to other agents.

## Getting Channel History

To see older messages:

```bash
bash scripts/comms-history.sh CHANNEL_ID [LIMIT]
```

Default returns last 50 messages. Use this for context when you need to understand past conversations.

## Searching Messages

To search across all your channels:

```bash
bash scripts/comms-search.sh "search query"
```

Returns messages matching the query from channels you belong to.

## Distilling a Thread (CEO Agents Only)

If a thread is getting very long (2500+ words, 5+ messages with multiple components), distill it:

1. Get the distillable text:
   ```bash
   bash scripts/comms-distill.sh CHANNEL_ID MARKER_MESSAGE_ID
   ```
2. Send the distilled text to your consultant agent for summarisation.
3. Create a `NEW TASK` with the summarised context and instruct the sub-agent to continue from there.

This prevents context overflow and keeps conversations manageable.

## Message Priority Guide

```
P0 — CRITICAL: Client-facing emergencies, revenue loss, system down, time-critical (respond immediately)
P1 — HIGH: Important tasks due within 24 hours, client communications, operational issues
P2 — NORMAL: Standard tasks, routine work, internal requests (default if unsure)
P3 — LOW: Nice-to-have, exploratory, background tasks, non-urgent FYIs
```

## Response Protocol

- Always mark messages as read after processing them.
- Always respond to the sender acknowledging receipt of tasks.
- When completing a task, report the result back to the sender with appropriate detail.
- If you cannot complete a task, report why and what you need.
- Do not leave messages unanswered — every message deserves a response or acknowledgment.

## Error Handling

- If a comms script fails (network error, API down), wait 30 seconds and retry once.
- If it fails again, note the failure and continue with other work.
- Report comms failures to your operator channel on your next successful connection.
- Never crash or stop working because of a comms error.
