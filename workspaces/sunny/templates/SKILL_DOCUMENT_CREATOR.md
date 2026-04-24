# SKILL.md — Document Creator Agent

> Version: 1.1 | Updated: 2026-04-11 | Applies to: Document Creator agents

> Technical reference for document creation capabilities and workflows.

---

## Supported Output Formats

### PowerPoint (.pptx)
**Library:** `python-pptx`

```python
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor

prs = Presentation()
# Use widescreen layout
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
```

**Slide creation pattern:**
```python
slide_layout = prs.slide_layouts[6]  # Blank layout
slide = prs.slides.add_slide(slide_layout)

# Add text box
txBox = slide.shapes.add_textbox(Inches(1), Inches(1), Inches(10), Inches(1))
tf = txBox.text_frame
tf.word_wrap = True
p = tf.paragraphs[0]
p.text = "Slide Title"
p.font.size = Pt(32)
p.font.bold = True
p.font.color.rgb = RGBColor(0x1A, 0x1A, 0x2E)
```

**Adding charts:**
```python
from pptx.chart.data import CategoryChartData
from pptx.enum.chart import XL_CHART_TYPE

chart_data = CategoryChartData()
chart_data.categories = ['Q1', 'Q2', 'Q3', 'Q4']
chart_data.add_series('Revenue', (150, 200, 180, 220))
chart = slide.shapes.add_chart(
    XL_CHART_TYPE.COLUMN_CLUSTERED,
    Inches(1), Inches(2), Inches(10), Inches(4.5),
    chart_data
).chart
```

**Adding images:**
```python
slide.shapes.add_picture("logo.png", Inches(0.5), Inches(0.3), height=Inches(0.8))
```

### PDF (.pdf)
**Library:** `fpdf2` (preferred) or `reportlab`

```python
from fpdf import FPDF

pdf = FPDF()
pdf.set_auto_page_break(auto=True, margin=15)
pdf.add_page()
pdf.set_font("Helvetica", "B", 24)
pdf.cell(0, 15, "Document Title", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_font("Helvetica", "", 11)
pdf.multi_cell(0, 6, "Body text goes here...")
pdf.output("output.pdf")
```

**Tables in PDF:**
```python
with pdf.table(col_widths=(40, 60, 40)) as table:
    header = table.row()
    for col in ["Name", "Description", "Value"]:
        header.cell(col)
    for item in data:
        row = table.row()
        row.cell(item["name"])
        row.cell(item["desc"])
        row.cell(str(item["value"]))
```

### Word (.docx)
**Library:** `python-docx`

```python
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

doc = Document()
doc.add_heading("Document Title", level=0)
doc.add_paragraph("Introduction text here.")
doc.add_heading("Section 1", level=1)
p = doc.add_paragraph("Content with ")
p.add_run("bold text").bold = True
doc.save("output.docx")
```

---

## Brand Templating

When brand guidelines are provided, store them as variables:

```python
# Brand config — customise per business
BRAND = {
    "primary_color": RGBColor(0x1A, 0x1A, 0x2E),
    "accent_color": RGBColor(0x00, 0x7A, 0xFF),
    "bg_color": RGBColor(0xFF, 0xFF, 0xFF),
    "font_heading": "Helvetica",
    "font_body": "Helvetica",
    "heading_size": Pt(28),
    "body_size": Pt(11),
    "logo_path": "assets/logo.png",
}
```

Apply consistently across all documents. If no brand guidelines are provided, use clean defaults — dark text on white, minimal accent colour, professional sans-serif fonts.

---

## Data Visualisation

When documents include data, use matplotlib or plotly to generate charts:

```python
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend

fig, ax = plt.subplots(figsize=(10, 5))
ax.bar(categories, values, color='#007AFF')
ax.set_title("Revenue by Quarter")
ax.spines[['top', 'right']].set_visible(False)
plt.tight_layout()
plt.savefig("chart.png", dpi=150, bbox_inches='tight')
plt.close()
```

Then embed in the document. Always export at 150+ DPI for sharp rendering.

---

## Quality Checklist

Run before every deliverable:

- [ ] No placeholder text remaining (`{{`, `TODO`, `FIXME`, `Lorem ipsum`)
- [ ] All numbers verified against source data
- [ ] Consistent fonts, sizes, and colours throughout
- [ ] Proper heading hierarchy (no skipped levels)
- [ ] All charts have labelled axes and titles
- [ ] Images are high resolution (not pixelated)
- [ ] Spelling and grammar checked
- [ ] File saved in the correct format
- [ ] File name is descriptive (not `output.pdf`)

---

## Message Bus Integration

All task communication follows `SKILL_COMMS.md`. Key patterns for this agent:

**Receiving a task:**
```
NEW TASK: Create Q3 revenue report as PDF
Data: [attached or referenced]
Audience: Board of directors
Format: PDF, 4-6 pages
Brand: Use company template
```

**Sending outline for approval:**
```
Outline for Q3 Revenue Report:
1. Executive Summary (1 page)
2. Revenue Breakdown by Channel (1 page, chart)
3. Cost Analysis (1 page, table)
4. YoY Comparison (1 page, chart)
5. Outlook & Recommendations (0.5 page)

Proceeding unless you want changes.
```

**Delivering completed document:**
```
COMPLETE: Q3 Revenue Report
File: /outputs/q3-revenue-report-2025.pdf
Pages: 5
Assumptions: Used FY24 data for YoY comparison. Excluded one-off legal costs from operating expenses.
Note: Chart on page 3 uses rounded figures for readability — exact numbers in the table below it.
```
