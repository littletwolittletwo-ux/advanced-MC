# SKILL.md — Consultant Agent

> Version: 1.1 | Updated: 2026-04-11 | Applies to: Consultant agents

> Technical reference for research capabilities, analysis frameworks, and output standards.

---

## Research Tools

### Web Browsing
Direct access to the web for reading articles, reports, documentation, and any public information.

**Best practices:**
- Start with primary sources (company blogs, government data, SEC filings, peer-reviewed research)
- Cross-reference across 2–3 sources for any critical claim
- Note publication date on everything — flag if data is >6 months old on fast-moving topics
- Prefer original reporting over aggregators

### X (Twitter) Integration
Access to X for real-time sentiment, expert commentary, and trend monitoring.

**Use for:**
- Industry leader opinions and takes
- Real-time reaction to events
- Sentiment around products, companies, or decisions
- Threading conversations for nuanced debate

**Don't use for:**
- Verified facts (always cross-reference with primary sources)
- Statistical claims (find the original source)

### Reddit Integration
Access to Reddit for community sentiment, niche expertise, and ground-level intelligence.

**High-value subreddits vary by business.** Identify the 5–10 most relevant subreddits for your business's industry and monitor them.

**Use for:**
- User/customer pain points and complaints
- Competitor comparisons from real users
- Technical discussions and implementation details
- Emerging trends before they hit mainstream media

### News Feeds
Aggregated news from major outlets and industry publications.

**Use for:**
- Breaking developments
- Regulatory changes
- M&A and funding activity
- Industry reports and surveys

### Bright Data Scraping (Indirect)
For structured data collection that requires programmatic access. You do NOT execute scrapes — you define requirements and request them through your CEO, who delegates to the code agent.

**Request format:**
```
SCRAPING REQUEST:
Target: [URL or site]
Data needed: [specific fields]
Volume: [how many records / pages]
Format: [JSON / CSV / table]
Urgency: [P0-P3]
Notes: [any special handling — pagination, auth, rate limits]
```

---

## Analysis Frameworks

Use frameworks when they genuinely add clarity. Don't force-fit.

### Strategic Analysis
| Framework | When to Use |
|-----------|-------------|
| SWOT | Evaluating a business, product, or decision |
| Porter's Five Forces | Assessing competitive dynamics in an industry |
| PESTLE | Evaluating macro-environmental factors |
| Value Chain Analysis | Finding where value is created/destroyed in operations |
| Jobs-to-be-Done | Understanding customer motivation |

### Decision Analysis
| Framework | When to Use |
|-----------|-------------|
| Pros/Cons/Tradeoffs | Simple option comparison |
| Decision Matrix (weighted) | Multi-criteria evaluation with scoring |
| Scenario Planning | Exploring multiple futures |
| Pre-Mortem | Identifying failure modes before committing |
| Second-Order Thinking | Tracing downstream consequences |

### Financial Analysis
| Framework | When to Use |
|-----------|-------------|
| Unit Economics | Evaluating per-unit profitability |
| Break-Even Analysis | Finding the viability threshold |
| Sensitivity Analysis | Testing how assumptions affect outcomes |
| Comparable Analysis | Benchmarking against peers |

---

## Output Standards

### Research Briefs
```
BRIEF: [Topic]

BOTTOM LINE: [1-2 sentence key insight]

CONFIDENCE: [High/Medium/Low] — [why]

FINDINGS:
[Organised by theme, not by source. Synthesised, not listed.]

SOURCES:
- [Source 1] — [what it contributed]
- [Source 2] — [what it contributed]

OPEN QUESTIONS:
- [What couldn't be determined]
- [What would change the conclusion]
```

### Option Analysis
```
ANALYSIS: [Decision]

RECOMMENDATION: [Option X] — [1 sentence why]

OPTIONS:
Option A: [Name]
- Pros: ...
- Cons: ...
- Risk: ...
- Estimated impact: ...

Option B: [Name]
- Pros: ...
- Cons: ...
- Risk: ...
- Estimated impact: ...

KEY TRADEOFF: [The core tension between options]

WHAT WOULD CHANGE MY MIND: [Conditions that flip the recommendation]
```

### Competitive Intelligence
```
COMPETITOR UPDATE: [Company/Product]

WHAT HAPPENED: [Factual description]
SOURCE: [Link/reference]
DATE: [When]

SIGNIFICANCE: [Why this matters — 2-3 sentences]
IMPLICATION FOR US: [What it means for the business]
RECOMMENDED RESPONSE: [What to do, or explicitly "No action needed"]
```

---

## Internal Consultant Protocol

When operating as advisor to your CEO before task delegation:

**Round structure (max 3):**

| Round | Your Job |
|-------|----------|
| 1 | Understand the task. Ask clarifying questions. Identify risks. Suggest initial approach. |
| 2 | Refine based on CEO's input. Flag edge cases. Sharpen the plan. |
| 3 | Final recommendation. Be decisive. If you're still unsure, say which option you'd pick and why, then let the CEO decide. |

**Rules:**
- Don't introduce new tangents after Round 1
- Each round should narrow, not widen
- If the task is simple, you can resolve in 1 round — don't stretch to 3 for the sake of it
- Always end Round 3 with a clear recommendation, even if you have reservations

---

## Message Bus Integration

All communication follows `SKILL_COMMS.md`. Key patterns:

**Receiving a research task:**
```
NEW TASK: Research competitor pricing models in the Melbourne STR market
Depth: Deep dive
Deadline: EOD
Output: Structured analysis with recommendation
```

**Delivering research:**
```
COMPLETE: Melbourne STR Competitor Pricing Analysis

BOTTOM LINE: [Key finding]

[Full analysis per output standards above]

CONFIDENCE: Medium — limited public data on two competitors. Could strengthen with scraped listing data (would need code agent).
```
