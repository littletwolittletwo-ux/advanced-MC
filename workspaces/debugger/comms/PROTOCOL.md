# Agent Comms — Protocol Rules

This document defines the operational protocols for inter-agent communication. SKILL.md teaches HOW to use comms. This document teaches WHEN and WHY.

## Delegation Protocol (CEO Agents)

When receiving a task from your superior:

1. **Acknowledge receipt immediately** (P1 message back to sender)
2. **Consult your consultant agent** for approach (if task is non-trivial)
3. **Max 3 rounds** with consultant, then decide
4. **Create NEW TASK** for each sub-agent delegation
5. **Set appropriate priority** on delegated tasks
6. **Monitor sub-agent responses**
7. **Synthesise results**
8. **Report back** to your superior with outcome

## Debugging Escalation Protocol

When a sub-agent reports failure:

**Step 1: Sub-agent self-debugging (3 attempts)**
- Sub-agent tries to fix the issue
- Back-and-forth with CEO for guidance (max 3 messages each way)

**Step 2: Consultant involvement (3 rounds)**
- CEO consults their consultant with the error details
- Consultant suggests alternative approaches
- CEO relays new approach to sub-agent (max 3 rounds)

**Step 3: Decision**
- If still failing, CEO decides one of:
  - a) Try a completely different approach (restart with NEW TASK)
  - b) Escalate to superior with full context
  - c) Mark task as blocked with clear explanation
- Never loop endlessly. **6 total attempts maximum**, then decide.

## Context Overflow Protocol (CEO Agents)

When a thread exceeds ~2500 words with 5+ distinct messages:

1. Run `comms-distill.sh` to get the full thread text
2. Send the text to your consultant agent: "Distill this thread into a concise summary preserving all key decisions, requirements, and current status"
3. Wait for the distilled summary
4. Create a **NEW TASK** in the same channel with:
   - The distilled summary as context
   - Clear instruction: "Continue from this context. Previous thread has been archived."
5. The sub-agent reads the new task and continues with fresh, clean context

## Advisory Board Protocol (Master VA Only)

When consulting the advisory board:

1. Post to the advisory group channel tagging all members:
   `@advisor-1 @advisor-2 @advisor-3 @advisor-4 [Question/context]`
2. Wait for responses (poll cycle will detect them)
3. Read all responses
4. If debate needed: tag specific agents with the other's point
   `@advisor-1 Advisor 3 raised [point]. What's your counter-argument?`
5. **Max 2 back-and-forths** between any two members
6. Synthesise all input into a decision
7. Delegate execution based on the synthesised strategy

## Handle Detection Rules (Board Members)

- Only respond to messages in group channels where your **@handle** appears
- If your handle is not in the message, **ignore it completely**
- When responding, address the specific question or point raised
- Keep responses focused and **under 500 words**
- Always ground your response in verifiable information
- If asked to debate another board member's point, address their specific argument
- You may use `REPLY_SKIP` to opt out of a debate round if you agree with the other's point
