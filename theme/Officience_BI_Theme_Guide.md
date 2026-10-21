# Officience BI – Power BI Theme Guide

Theme file: `Officience_BI_Theme.json` (Power BI Desktop → View → Themes → Browse for themes).
Reference images: `PBI_Example_1_Executive_Overview.png`, `PBI_Example_2_Finance_PnL.png`, `PBI_Example_3_Delivery_Operations.png`, `PBI_Example_4_Style_Guide.png`.

## Core rule
Primary blue `#1F49BF` is an **accent, not a fill**. Neutrals carry the structure. Target blue ≤ ~10–15% of visible page area.

## Colour roles
| Role | Hex | Use |
|---|---|---|
| Brand Blue | #1F49BF | Series 1, KPI accent bar, table header underline, totals, active tab, "good" |
| Ink | #0F1219 | Titles, values, body text |
| Slate (derived) | #5F6368 | Labels, axis text, subtitles |
| Grey | #A0A0A0 | Comparison / prior-year series, inactive items |
| Canvas | #F7F7F7 | Page background |
| White | #FFFFFF | Visual (card) background |
| Border (derived) | #E4E6EA | Card borders, 8px radius, no shadow |
| Orange | #FD941D | Series 2, neutral / at-risk, targets |
| Red | #DD3C57 | Bad / negative variance / delayed |
| Blue tint (derived) | #8FA4DF | Increases, secondary blue series |
| Blue light (derived) | #C7D1EF / #EEF1FA | Prior-year bars, total-row fill, heat-scale min |
| Yellow / Pink | #FFCE00 / #FFBFC7 | Extra series only, never text |

Data colour order: #1F49BF, #FD941D, #A0A0A0, #DD3C57, #8FA4DF, #FFCE00, #0F1219, #FFBFC7, …

Sentiment: good = blue, neutral = orange, bad = red (palette has no green).

## Layout conventions
- 1920×1080 page, #F7F7F7 canvas, white header strip with blue logo, page title (22 bold) + subtitle, slicers top-right.
- Page tabs under header; active tab = ink text + blue underline.
- KPI row: 4 cards with 4px blue left accent bar, label / big value / ▲▼ delta vs prior year, optional light-blue sparkline.
- Highlight pattern: one series blue, comparisons grey or light blue (e.g. FY26 blue vs FY25 #C7D1EF; above-target bars blue, others grey).
- Tables: light-grey header, blue bottom border, zebra #FAFAFB, total row #EEF1FA bold; positive variance blue, negative red.

## Typography
Segoe UI (brand font Lexend only if installed on all viewers' PCs). Page title 22 bold · KPI value 26 semibold · visual title 11 semibold · labels 9 regular #5F6368.

## Avoid
Blue page/header backgrounds, blue-filled cards, monochrome all-blue series, yellow/pink text, drop shadows.
