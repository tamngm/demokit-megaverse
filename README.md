## Project Purpose

**Retail Megaverse** is a reference implementation designed to demonstrate how modern retail analytics can evolve from descriptive reporting to intelligent, ad-hoc exploration.

## Project Process
- Link to the diagram
https://viewer.diagrams.net/?tags=%7B%7D&lightbox=1&highlight=0000ff&edit=_blank&layers=1&nav=1&dark=auto#G196jzwpBq4qo-QhL-9obHPrfyCV3kgRYI

### 🎯 Core Objectives
1. **Bridge Business & Data Logic**  
   - Start with a business-first logical data model that maps retail KPIs directly to underlying data entities.
   - Enable non-technical stakeholders to trace metrics back to source logic without SQL.

2. **Enable Deep-Dive Analytics, Not Just Dashboards**  
   - Move beyond "what sold last week" to answer complex questions like:  
     - *"Which customer segments are most sensitive to promo timing?"*  
     - *"What-if we adjust pricing in Region X — how does it ripple through inventory and margin?"*  
   - Provide reusable ML/AI building blocks (clustering, forecasting, anomaly detection) that analysts can compose ad-hoc.

3. **Demonstrate Scalable, Cloud-Native Architecture**  
   - Showcase a lightweight, reproducible stack: raw data in S3 → schema-on-read with Athena → interactive visualization in Power BI.  
   - Keep infrastructure simple enough for a demo, yet realistic enough to extend to production.

4. **Centralize Knowledge Without Overhead**  
   - Use GitHub as the single source of truth for code, schemas, and documentation — no Confluence required.  
   - Make business rules, data definitions, and model assumptions transparent, versioned, and searchable.

### 🚫 What This Project Is NOT
- ❌ Not another static Power BI report  
- ❌ Not a black-box AI prototype with no business context  
- ❌ Not a migration blueprint (though patterns are reusable)

### ✅ Success Looks Like
- A business user can open the repo, read `docs/business/use-cases/`, and understand *which analysis to run* and *what data it needs*.  
- A data engineer can clone the repo, deploy the Athena schema via script, and extend the model.  
- An ML practitioner can plug in a new model using the documented feature schema and evaluation framework.

### Business Logics Model
- Link to diagram: https://viewer.diagrams.net/?tags=%7B%7D&lightbox=1&highlight=0000ff&edit=_blank&layers=1&nav=1&dark=auto#G196jzwpBq4qo-QhL-9obHPrfyCV3kgRYI

### Technical Structures
## Engineering Pipeline
- From external source to S3 storage back and forth during the transformation flow.
- Link to diagram: https://viewer.diagrams.net/?tags=%7B%7D&lightbox=1&highlight=0000ff&edit=_blank&layers=1&nav=1&dark=auto#G196jzwpBq4qo-QhL-9obHPrfyCV3kgRYI

## How to collaborate on Git
1. Clone repo → `git clone ...`
2. Read [How to Collaborate on Git](src/docs/git-how-to.md)
3. Check above for business logic & data models

Visual Git Workflow (src/docs/git-collab-workflow.md)

## 🚦 Golden Rules
1. **Never push directly to `main`** — always use a feature branch
2. **One PR = One logical change** — keep reviews fast
3. **Write clear PR titles** — e.g., `feat: add customer segmentation model`
