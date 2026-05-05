---
name: morae-brand
description: >
  Universal Morae Global brand identity skill. Use this skill whenever creating ANY deliverable
  that should carry Morae branding — Power BI dashboards, Word documents, PDFs, PowerPoint decks,
  HTML pages, emails, one-pagers, reports, proposals, React artifacts, or any other visual output.
  Triggers include: mentions of Morae branding, Morae colors, Morae theme, "make it on-brand",
  "use our brand", "Morae style", brand guidelines, brand compliance, company colors, company
  fonts, IBM Plex Sans in a Morae context, or any request to produce a professional deliverable
  for Morae Global or CLUTCH Group. Also triggers when the user asks Claude to review something
  for brand consistency, or when creating client-facing materials. If the user is at Morae and
  asks for any formatted output, use this skill to ensure brand compliance. Even casual requests
  like "make it look nice" or "clean this up" from a Morae user should trigger this skill.
---

# Morae Global Brand Identity Skill

This skill contains the complete Morae brand system derived from the official Morae Brand Identity Guidelines (v2.2, Q2 2023). Apply these standards to every deliverable — dashboards, documents, presentations, web pages, PDFs, or anything else that represents Morae.

## Brand Personality

Morae's brand personality should come through in the tone, design, and structure of every deliverable:

- **Collaborative and Open** — transparent layouts, clear data, no hidden complexity.
- **Warm and Empathetic** — approachable color palette, generous whitespace, conversational labels.
- **Focused and Accountable** — precise data, clean formatting, no clutter.
- **Curious and Creative** — modern typography, bold accent colors, willingness to break from stale templates.

**Writing style:** Be concise, conversational, aspirational, and clear. Short sentences. Simple language. Engage the reader like a peer, not a parent. When legal terminology is required, make everything around it as simple as possible.

---

## Color Palette

### Primary Colors

The Morae palette is warm-spectrum, with orange at its heart. These five colors derive from the brand mark and should be the dominant accent colors in all deliverables.

| Name               | HEX       | RGB             | Usage                                                     |
|--------------------|-----------|-----------------|-----------------------------------------------------------|
| Morae Yellow       | `#FFBD00` | 255 / 189 / 0   | Positive indicators, highlights, secondary accents        |
| Morae Light Orange | `#FF9400` | 255 / 148 / 0   | Supporting accents, hover states, secondary charts        |
| Morae Orange       | `#FF6900` | 255 / 105 / 0   | **Primary brand accent** — use first for any single-color need |
| Morae Bright Orange| `#FF3600` | 255 / 54 / 0    | Emphasis, alerts, calls to action                         |
| Morae Red          | `#FF0000` | 255 / 0 / 0     | Negative indicators, critical alerts, urgency             |

**Default color sequence** when multiple colors are needed (charts, icons, categories): Morae Orange → Morae Yellow → Morae Bright Orange → Morae Light Orange → Morae Red.

### Secondary Colors

Neutral tones for backgrounds, text, and structural elements.

| Name             | HEX       | RGB             | Usage                                                    |
|------------------|-----------|-----------------|----------------------------------------------------------|
| Morae Off-White  | `#EDE5DE` | 237 / 229 / 222 | **Primary background** — preferred over pure white       |
| Pure White       | `#FFFFFF` | 255 / 255 / 255 | Cards, content panels on Off-White backgrounds           |
| Morae Mid Gray   | `#CFC8C2` | 208 / 200 / 194 | Borders, dividers, gridlines, disabled/muted elements    |
| Morae Dark Gray  | `#252525` | 37 / 37 / 37    | Body text, captions, secondary labels                    |
| Morae Black      | `#101010` | 16 / 16 / 16    | Headlines, titles, high-contrast text, dark backgrounds  |

### Gradients

| Name              | From       | To         | Angle | Usage                                      |
|-------------------|-----------|-----------|-------|--------------------------------------------|
| Morae Gradient 01 | `#FF0000` | `#FF9400` | -45°  | Title bars, banners, accent strips. Use for text/icon legibility. |
| Morae Gradient 02 | `#FF0000` | `#FFBD00` | -45°  | Supergraphics and decorative use only. Not for text overlays. |

### Color Rules

- **Backgrounds:** Default to Morae Off-White (`#EDE5DE`), not pure white. Use pure white for content cards/panels layered on top of Off-White to create subtle depth.
- **Dark mode:** Use Morae Black (`#101010`) as the background with Off-White text and primary warm colors for accents.
- **No off-brand colors:** Never use saturated blues, greens, or purples as primary colors. If you need more colors than the five primaries, use tints (reduced opacity) of existing palette colors.
- **Conditional formatting / status indicators:** Use Morae Yellow for positive/good, Morae Mid Gray for neutral, Morae Red for negative/bad. Do NOT use green — it is not a Morae brand color.
- **Text on backgrounds:** On Morae Black → use Off-White, Yellow, Light Orange, Orange, Bright Orange, or Red for text. On Morae Off-White → use Morae Black, Dark Gray, Red, Bright Orange, or Orange for text. Avoid warm-on-warm combinations (e.g., Yellow text on Orange background).
- **Links and interactive elements:** Use Morae Orange (`#FF6900`) for hyperlinks and clickable elements. Hover state can shift to Morae Bright Orange (`#FF3600`).

---

## Typography

### Brand Typeface: IBM Plex Sans

Morae's typeface is **IBM Plex Sans**, a modern and flexible sans-serif family available free from Google Fonts and IBM. It is the only typeface family needed for all Morae materials.

For alternative headline needs (brochures, printed collateral), **IBM Plex Serif** (Light or Regular) may be used.

### Available Weights
- ExtraLight / ExtraLight Italic
- Light / Light Italic
- Regular / Italic
- Medium / Medium Italic
- **Bold / Bold Italic**

### Type Hierarchy

| Element                  | Typeface        | Weight      | Size Range    | Color            |
|--------------------------|-----------------|-------------|---------------|------------------|
| Document/page title      | IBM Plex Sans   | Bold        | 24–36pt       | Morae Black      |
| Section heading (H2)     | IBM Plex Sans   | Medium      | 18–24pt       | Morae Black      |
| Subsection heading (H3)  | IBM Plex Sans   | Medium      | 14–16pt       | Morae Dark Gray  |
| Body text                | IBM Plex Sans   | Regular     | 10–12pt       | Morae Dark Gray  |
| Captions / labels        | IBM Plex Sans   | Light       | 9–10pt        | Morae Dark Gray  |
| KPI / callout numbers    | IBM Plex Sans   | Bold        | 28–48pt       | Morae Black      |
| Code / monospace         | IBM Plex Mono   | Regular     | 10pt          | Morae Dark Gray  |

### Typesetting Rules
- **Alignment:** Left-aligned by default. Center-aligned for titles in centered layouts.
- **Tracking:** 0 / Optical (default). Do not letter-space.
- **Leading:** Tight but not clashing — roughly 120–130% of font size.
- **Sentence case** for titles and headings (not ALL CAPS unless it's a short label like "KPI" or "YTD").

### Fallback Fonts
When IBM Plex Sans is unavailable in a given tool:
- **Power BI:** Segoe UI
- **Microsoft Office (Word/PPT/Excel):** Calibri or Segoe UI
- **Web / HTML / React:** Load IBM Plex Sans from Google Fonts (`https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@200;300;400;500;700&display=swap`). Fallback stack: `'IBM Plex Sans', 'Segoe UI', -apple-system, sans-serif`.

---

## Logo Usage

### Mark Variants
- **Full color gradient mark:** Primary version — use on dark or light backgrounds.
- **Mono Black mark:** For use on light backgrounds when color is not available.
- **Mono White mark:** For use on dark or gradient backgrounds.

### Lockup Options
- **Landscape:** Mark + "Morae" wordmark side-by-side. Use when horizontal space is available.
- **Centered:** Mark above "Morae" wordmark, stacked. Use in centered/portrait layouts.

### Placement Rules
- Place logo in any corner or centered. Bottom-left is typical for documents.
- Maintain clearance zone (based on a 5-line block of the mark's letterform) — don't crowd the logo with other elements.
- Minimum sizes: Mark alone = 40px/14mm. Landscape lockup = 20px/30mm width.

---

## Visual Design System

### Sub-Graphics
Morae's visual language is built from the DNA of the logo mark. Four sub-graphic styles can be used as decorative elements, section dividers, or background textures:

1. **Diagonal (Primary)** — 45-degree angled bars. Use this first and most often.
2. **Circular** — Concentric arcs. Secondary option.
3. **Vertical** — Vertical bars of varying width. Secondary option.
4. **Horizontal** — Horizontal bars of varying width. Secondary option.

These can appear in Morae Black/Off-White (tone-on-tone) or in the primary gradient colors. Always include at least one full 5-bar group when using diagonal sub-graphics.

### Imagery Style
- Prefer photography with orange and red hues — either naturally present or applied as a warm color overlay.
- Black-and-white photography with selective Morae Orange color accent is an approved treatment.
- Avoid cold-toned or blue-cast imagery.

---

## Applying the Brand by Deliverable Type

### Power BI Dashboards
- Page background: Morae Off-White. Visual backgrounds: Pure White.
- Data series colors: Use the primary 5-color sequence.
- Typography: IBM Plex Sans (or Segoe UI fallback).
- Conditional formatting: Yellow/Gray/Red — never green.
- KPI cards: Bold callout number in Morae Black, label in Morae Dark Gray, trend indicator in Yellow (▲) or Red (▼).
- Apply the Morae theme JSON (see Power BI skill for the full JSON, or generate from the palette above).

### Word Documents / PDFs
- Use Morae Off-White as a subtle page background tint if the tool supports it, otherwise pure white.
- Headings in IBM Plex Sans Bold (Morae Black). Body in IBM Plex Sans Regular (Morae Dark Gray).
- Accent color for horizontal rules, table headers, and callout boxes: Morae Orange.
- Footer: Morae mark (small, bottom-left) + document title + page number in Morae Mid Gray.
- Table styling: Header row in Morae Orange with Off-White text. Alternating rows in Off-White / Pure White. Borders in Morae Mid Gray.

### PowerPoint / Presentations
- Slide background: Morae Off-White or Morae Black (alternate for impact slides).
- Title slides: Large IBM Plex Sans Bold title, diagonal sub-graphic as decorative element, Morae gradient mark.
- Content slides: Clean grid layout. KPIs at top in cards. Charts use brand color sequence.
- Accent elements: Use diagonal bar sub-graphics cropped at slide edges for visual interest.
- Avoid using more than 2–3 brand colors per slide to keep things focused.

### HTML / React Artifacts
- Load IBM Plex Sans from Google Fonts.
- Background: `#EDE5DE`. Card backgrounds: `#FFFFFF` with `1px solid #CFC8C2` border and subtle `border-radius: 8px`.
- Primary button: `background: #FF6900; color: #FFFFFF; font-family: 'IBM Plex Sans'; font-weight: 500`.
- Hover state: `background: #FF3600`.
- Text: `color: #252525` for body, `color: #101010` for headings.
- Links: `color: #FF6900`.

### Emails / Internal Communications
- Keep it simple. IBM Plex Sans (or fallback) for text.
- Use Morae Orange sparingly for emphasis — a colored horizontal rule or a single highlighted callout.
- Sign off with the Morae landscape lockup if appropriate.

---

## Quick Reference: Do's and Don'ts

**Do:**
- Use Morae Off-White as your default background
- Lead with Morae Orange as the primary accent
- Use IBM Plex Sans consistently
- Apply the warm Yellow → Orange → Red spectrum for data series
- Keep layouts clean with generous whitespace
- Use the diagonal sub-graphic pattern for visual interest

**Don't:**
- Use green for positive indicators (use Morae Yellow)
- Use blues, purples, or cool-toned colors as primary accents
- Use ALL CAPS for headings (sentence case only)
- Crowd the logo — maintain clearance zones
- Use Gradient 02 (Red → Yellow) for text backgrounds — it's for supergraphics only
- Mix multiple typeface families — IBM Plex Sans handles everything

---

## Response Guidelines

1. **Always apply** these brand standards to any deliverable you produce for the user — documents, presentations, dashboards, HTML artifacts, code outputs with UI, etc.
2. **Be specific** about colors — reference Morae color names AND hex values (e.g., "Morae Orange `#FF6900`"), never vague terms like "use orange."
3. **Flag off-brand elements** when reviewing user-provided content — call out blues, greens, default tool themes, or non-Plex fonts.
4. **Provide copy-paste-ready values** — hex codes, RGB values, CSS snippets, theme JSON, font import URLs.
5. **Match the brand personality** in your communication style: concise, warm, clear, collaborative.
