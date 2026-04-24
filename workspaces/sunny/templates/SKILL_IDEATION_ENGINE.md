# SKILL.md — Ideation Engine Agent

> Version: 1.1 | Updated: 2026-04-11 | Applies to: Ideation Engine agents

> Technical reference for scanning sources, filtering signals, and output formats.

---

## Source Scanning

### X (Twitter)
**What to monitor:**
- Industry hashtags and keywords (configured per business)
- Competitor accounts (list maintained by CEO)
- Key influencers and thought leaders (list maintained by CEO)
- Trending topics with industry overlap

**Signal quality tiers:**
| Tier | Source | Trust Level |
|------|--------|-------------|
| A | Verified industry experts, company official accounts | High — can cite directly |
| B | Popular creators, analysts, journalists | Medium — cross-reference before citing as fact |
| C | Anonymous accounts, viral tweets | Low — useful for sentiment only, never cite as fact |

### Instagram
**What to monitor:**
- Competitor accounts (grid posts, Stories, Reels)
- Industry hashtags
- Influencer activity in the space
- Aesthetic and branding trends

**Extraction focus:**
- Visual style shifts (color palettes, photography styles, graphic trends)
- Content format trends (carousel vs. Reel vs. static)
- Engagement patterns (what gets saves/shares vs. just likes)
- Caption strategies and CTAs

### TikTok
**What to monitor:**
- Hashtags relevant to the business's industry
- Competitor accounts
- Trending sounds that could be leveraged
- "Day in the life" or behind-the-scenes content in the industry

**Extraction focus:**
- Content formats that drive high engagement
- Hook patterns (first 3 seconds)
- Sound/music trends with industry crossover
- Comment sentiment (what audiences actually say)

### Reddit
**Key subreddits:** Configured per business. Typically 5–10 subreddits covering:
- The direct industry
- Adjacent industries
- Customer/user communities
- Business/strategy communities
- Local market communities

**Extraction focus:**
- Pain points repeated across multiple threads
- Feature requests and wishlists
- Competitor praise and complaints
- Emerging terminology or concepts

### News & Publications
**Sources:** Major news outlets + industry-specific publications (configured per business).

**Extraction focus:**
- Regulatory changes
- Market data and reports
- M&A and funding
- Technology announcements

---

## Signal Filtering

Every signal must pass the **RAA test** before surfacing:

| Filter | Question | Threshold |
|--------|----------|-----------|
| **R** — Real | Is this verified/verifiable? | Must be from a credible source or cross-referenced |
| **A** — Actionable | Can the business do something with this? | Must have a clear "so what" |
| **A** — Aligned | Does this connect to the business's strategy or market? | Must relate to current operations or strategic goals |

**Discard if:**
- It's interesting but irrelevant to the business
- It's relevant but not actionable
- It's a single data point with no supporting signals
- It's older than 7 days (for trend reports; longer for strategic signals)

---

## Output Formats

### Trend Report
```
TREND REPORT: [Period — e.g., "Week of April 7, 2026"]

TOP SIGNALS:

1. [SIGNAL NAME]
   Platform: [Where you found it]
   What: [What's happening — 2-3 sentences]
   Why it matters: [Business relevance]
   Action: [What to do]
   Urgency: [Act now / This week / Monitor / Long-term]
   Source: [Link or reference]

2. [SIGNAL NAME]
   ...

WATCHLIST (not actionable yet, but tracking):
- [Signal] — [Why watching] — [What would make it actionable]

COMPETITOR MOVES:
- [Competitor] did [what] on [platform] — [significance]
```

### Idea Brief
```
IDEA: [Short title]

SPARK: [What you saw and where — with link]

THE IDEA:
[2-3 sentences describing what the business could do]

OPPORTUNITY:
- Estimated impact: [qualitative — low/medium/high]
- Audience: [Who benefits]
- Timing: [Why now]

EFFORT:
- Complexity: [Low/Medium/High]
- Resources needed: [What team/tools/budget]
- Time to execute: [Rough estimate]

EXAMPLES:
- [Link 1] — [How someone else did something similar]
- [Link 2] — [Another reference]

RECOMMENDATION: [Do it / Test it / Park it / Skip it]
```

### Opportunity Alert (Time-Sensitive)
```
⚡ OPPORTUNITY ALERT

SIGNAL: [What happened]
SOURCE: [Link]
WINDOW: [How long this opportunity is open]

THE PLAY:
[What to do — specific and actionable]

UPSIDE: [What you gain]
DOWNSIDE OF INACTION: [What happens if ignored]
EFFORT: [What it takes]

PRIORITY: [P0/P1/P2]
```

### Competitive Intelligence Update
```
COMPETITOR: [Name]

ACTION: [What they did]
PLATFORM: [Where]
DATE: [When]
SOURCE: [Link]

ANALYSIS:
[Why they did it, what it signals strategically — 3-5 sentences]

IMPLICATION:
[How this affects the business — 2-3 sentences]

RESPONSE: [Recommended action or "No response needed"]
```

---

## Monitoring Configuration

Your CEO will provide:

```json
{
  "scan_frequency": "daily",
  "report_frequency": "weekly",
  "alert_threshold": "P1",
  "competitors": ["Competitor A", "Competitor B"],
  "keywords": ["keyword1", "keyword2"],
  "platforms": ["x", "instagram", "tiktok", "reddit", "news"],
  "subreddits": ["r/sub1", "r/sub2"],
  "influencers_x": ["@handle1", "@handle2"],
  "industry_hashtags": ["#tag1", "#tag2"]
}
```

Adjust your scanning based on this config. If it's not set yet, ask your CEO to define it.

---

## Message Bus Integration

All communication follows `SKILL_COMMS.md`.

**Delivering a scheduled report:**
```
WEEKLY TREND REPORT: April 7-13, 2026

[Full report per format above]

Next report: April 20, 2026. Ping me if you want anything investigated deeper.
```

**Flagging an urgent opportunity:**
```
⚡ OPPORTUNITY ALERT — P1

[Full alert per format above]

Flagging now because the window is short. Awaiting your call.
```
