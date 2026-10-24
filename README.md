# 🛒 E-Commerce Customer 360 & Multi-Touch Marketing Attribution Engine

An end-to-end data analytics engineering pipeline built using **Google BigQuery** and **Looker Studio** on e-commerce transaction and clickstream event datasets.

---

## 🏗️ Architecture Pipeline

```mermaid
flowchart LR
    A[GA4 / Web Events] --> C[(Google Cloud BigQuery)]
    B[Synthetic CRM & Ad Spend] --> C
    
    subgraph Transformation Layer [SQL Modeling]
        C --> D[1. Identity Resolution & Session Stitching]
        D --> E[2. RFM Segmentation & Customer 360]
        D --> F[3. Multi-Touch Attribution: First, Last, Linear, Time-Decay]
        F --> G[4. CAC & ROAS Engine]
    end
    
    G --> H[Looker Studio Executive Dashboard]
    E --> H
