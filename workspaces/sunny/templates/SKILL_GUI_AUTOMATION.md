# SKILL.md — GUI Automation Agent

> Version: 1.1 | Updated: 2026-04-11 | Applies to: GUI Automation agents

> Technical reference for browser automation tools, patterns, and failure handling.

---

## Toolchain Reference

### Playwright

**Installation:**
```bash
pip install playwright
playwright install chromium
```

**Basic pattern:**
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=False)  # headed for anti-bot sites
    context = browser.new_context(
        viewport={"width": 1920, "height": 1080},
        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    )
    page = context.new_page()
    page.goto("https://example.com")
    
    # Wait for element, then interact
    page.wait_for_selector("#login-button", timeout=10000)
    page.click("#login-button")
    
    # Fill form
    page.fill("#email", "user@example.com")
    page.fill("#password", credentials["password"])
    
    # Screenshot
    page.screenshot(path="evidence.png", full_page=True)
    
    browser.close()
```

**Key methods:**
| Method | Use |
|--------|-----|
| `page.goto(url)` | Navigate to URL |
| `page.click(selector)` | Click element |
| `page.fill(selector, value)` | Clear and type into input |
| `page.type(selector, value)` | Type character by character (more human-like) |
| `page.select_option(selector, value)` | Select dropdown option |
| `page.wait_for_selector(selector)` | Wait for element to appear |
| `page.wait_for_load_state("networkidle")` | Wait for network to settle |
| `page.screenshot(path=...)` | Capture screenshot |
| `page.content()` | Get page HTML |
| `page.evaluate(js)` | Run JavaScript on page |
| `page.locator(selector)` | Get a locator for chained operations |

**Selector strategies (in order of preference):**
1. `data-testid` or `data-cy` attributes — most stable
2. `#id` — stable if IDs are semantic
3. `[aria-label="..."]` — good for accessibility-designed sites
4. `text="Visible Text"` — Playwright-specific, resilient to DOM changes
5. `.class-name` — fragile, use only as fallback
6. `xpath=//div[@class="..."]` — last resort

### Patchwright

Enhanced Playwright wrapper with AI-powered element targeting:

```python
from patchwright import PatchPage

page = PatchPage(playwright_page)

# Natural language targeting — finds element by description
await page.ai_click("the blue Submit button at the bottom of the form")
await page.ai_fill("email input field", "user@example.com")

# Self-healing selectors
await page.resilient_click("#submit-btn", fallbacks=[
    "button:has-text('Submit')",
    "[type='submit']",
    "form >> button:last-child"
])
```

Use Patchwright when:
- Standard selectors are brittle or frequently changing
- The site has dynamic/generated class names
- You need natural language fallback for element targeting

### Peekaboo (Visual Understanding)

Screen analysis for when DOM-based approaches fail:

```python
from peekaboo import ScreenAnalyzer

analyzer = ScreenAnalyzer()

# Capture and analyse current screen
screenshot = page.screenshot()
analysis = analyzer.analyze(screenshot)

# Find element by visual description
element = analyzer.find("the red Cancel button in the modal dialog")
# Returns: { x, y, width, height, confidence }

# Extract text from a region
text = analyzer.ocr(screenshot, region=(100, 200, 400, 250))

# Compare two screenshots for changes
diff = analyzer.diff(screenshot_before, screenshot_after)
```

Use Peekaboo when:
- Canvas-based or image-heavy UIs
- Elements have no reliable DOM selectors
- You need to verify visual state (not just DOM state)
- OCR is needed for text in images

---

## Common Workflow Patterns

### Authentication Flow
```python
async def login(page, credentials):
    await page.goto(credentials["login_url"])
    await page.fill("#email", credentials["email"])
    await page.fill("#password", credentials["password"])
    await page.click("#login-button")
    
    # Wait for successful login indicator
    try:
        await page.wait_for_selector("#dashboard", timeout=15000)
        return True
    except:
        # Check for error message
        error = await page.text_content(".error-message")
        return False, error
```

### Pagination Loop
```python
async def scrape_all_pages(page, url):
    results = []
    await page.goto(url)
    
    while True:
        # Extract data from current page
        items = await page.query_selector_all(".item")
        for item in items:
            results.append(await extract_item(item))
        
        # Check for next page
        next_btn = await page.query_selector(".next-page:not(.disabled)")
        if not next_btn:
            break
        
        await next_btn.click()
        await page.wait_for_load_state("networkidle")
        await page.wait_for_timeout(1000)  # Human-like delay
    
    return results
```

### Form Filling from Structured Data
```python
async def fill_form(page, data):
    """Fill a form from a dictionary of field_selector: value pairs."""
    for selector, value in data.items():
        element = await page.query_selector(selector)
        tag = await element.evaluate("el => el.tagName.toLowerCase()")
        
        if tag == "select":
            await page.select_option(selector, value)
        elif tag == "input":
            input_type = await element.get_attribute("type")
            if input_type == "checkbox":
                if value:
                    await element.check()
            elif input_type == "file":
                await element.set_input_files(value)
            else:
                await page.fill(selector, str(value))
        elif tag == "textarea":
            await page.fill(selector, str(value))
```

### Screenshot Evidence
```python
async def evidence_screenshot(page, name, step_description):
    """Capture timestamped evidence screenshot."""
    from datetime import datetime
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    path = f"evidence/{timestamp}_{name}.png"
    await page.screenshot(path=path, full_page=False)
    return {
        "path": path,
        "step": step_description,
        "timestamp": timestamp,
        "url": page.url
    }
```

---

## Failure Handling

### Retry Pattern
```python
async def retry_action(action, max_retries=3, delay=2):
    for attempt in range(max_retries):
        try:
            return await action()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            await asyncio.sleep(delay * (attempt + 1))
```

### Selector Fallback Chain
```python
async def resilient_find(page, selectors):
    """Try multiple selectors in order until one works."""
    for selector in selectors:
        try:
            element = await page.wait_for_selector(selector, timeout=3000)
            if element:
                return element
        except:
            continue
    raise Exception(f"None of the selectors worked: {selectors}")
```

### Anti-Bot Detection Handling
```python
# Human-like typing
async def human_type(page, selector, text):
    import random
    await page.click(selector)
    for char in text:
        await page.keyboard.type(char)
        await page.wait_for_timeout(random.randint(50, 150))

# Random delays between actions
async def human_delay():
    import random
    await asyncio.sleep(random.uniform(0.5, 2.0))
```

---

## Self-Learning Log Format

After each task, record:

```json
{
  "site": "https://example.com",
  "task_type": "form_fill",
  "date": "2026-04-11",
  "selectors_used": {
    "login_email": "#email",
    "login_password": "#password",
    "submit": "button:has-text('Sign In')"
  },
  "selectors_failed": {
    "#old-submit-id": "Replaced with class-based button"
  },
  "failure_modes": [
    "CAPTCHA appeared after 3rd login attempt"
  ],
  "resolutions": [
    "Added 5s delay between login attempts"
  ],
  "reliability": "medium",
  "notes": "Site has Cloudflare protection. Must use headed mode."
}
```

Reference this log when the same site comes up in future tasks.

---

## Message Bus Integration

All communication follows `SKILL_COMMS.md`.

**Reporting progress with evidence:**
```
Step 3/7 complete: Logged into platform successfully.
Screenshot: evidence/20260411_143022_login_success.png
Proceeding to data extraction.
```

**Reporting a failure:**
```
BLOCKED at Step 4: CAPTCHA triggered during form submission.
Screenshot: evidence/20260411_143522_captcha_block.png
URL: https://example.com/submit

Attempted:
1. Retried after 10s delay — same result
2. Cleared cookies and re-authenticated — CAPTCHA again
3. Switched to headed mode — still triggered

Hypothesis: Rate limiting triggered by rapid form submissions.
Recommendation: Wait 30 min and retry, or use a different IP.

Awaiting direction.
```
