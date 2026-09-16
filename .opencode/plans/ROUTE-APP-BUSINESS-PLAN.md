# Route App — Distribution Route Management System

## Executive Summary

**Route App** is a SaaS distribution route management platform built for FMCG distributors, logistics companies, and supply chain operators in India — starting with Kozhikode, Kerala. It solves the core problem of **inefficient delivery routing, poor driver accountability, and zero visibility into field operations** for small-to-medium distributors.

Most Indian distributors still manage routes via WhatsApp messages, paper charts, or Excel sheets. A 5-route distributor with 35 customers loses **15-20% of productive time** to suboptimal routing, missed deliveries, and manual coordination. Route App eliminates this with smart route planning, real-time trip tracking, and an approval workflow that keeps supervisors in control.

---

## Business Model

### Target Customers
| Segment | Size (India) | Pain Point | Willingness to Pay |
|---------|-------------|------------|-------------------|
| FMCG Distributors (1-20 routes) | ~500,000 | Manual routing, no visibility | Rs.2,000-8,000/month |
| Pharmacy/Medical Distributors | ~100,000 | Time-sensitive deliveries, cold chain | Rs.3,000-10,000/month |
| Bakery/Food Distributors | ~200,000 | Daily route planning, perishable goods | Rs.2,000-6,000/month |
| Regional Logistics Companies | ~50,000 | Multi-route fleet management | Rs.10,000-50,000/month |

### Revenue Model
| Tier | Price (Rs./month) | Routes | Customers | Features |
|------|-----------------|--------|-----------|----------|
| **Starter** | Rs.1,999 | 3 | 50 | Route planning, driver app, basic analytics |
| **Growth** | Rs.4,999 | 10 | 200 | + Smart insertion, approval workflow, version history |
| **Pro** | Rs.9,999 | Unlimited | Unlimited | + API access, bulk import, custom branding, priority support |
| **Enterprise** | Custom | Multi-depot | Unlimited | + White-label, on-premise, SLA, dedicated account manager |

### Unit Economics (Growth Tier)
| Metric | Value |
|--------|-------|
| ARPU | Rs.4,999/month |
| CAC (digital marketing) | Rs.3,000 |
| LTV (18-month avg retention) | Rs.89,982 |
| LTV:CAC Ratio | 30:1 |
| Gross Margin | ~85% (cloud-hosted SaaS) |
| Payback Period | <1 month |

---

## User Personas

### 1. Rajesh — Distribution Owner (Admin)
- **Age:** 35-55
- **Business:** Runs a FMCG distribution company with 5 routes, 35+ customers, 5 delivery vehicles
- **Current tools:** WhatsApp groups, paper route charts, Excel for tracking
- **Pain points:**
  - Does not know if driver actually visited all stops
  - Customers complain about missed or late deliveries
  - Adding a new customer to a route takes 30+ minutes of manual calculation
  - No data on driver performance or route efficiency
- **Goals:** Reduce fuel costs, improve delivery accuracy, get visibility into field ops
- **Willingness to pay:** Rs.5,000/month if it saves even 1 hour/day of coordination

### 2. Arun — Delivery Driver
- **Age:** 22-40
- **Role:** Drives a delivery van on Route 01 (Mavoor Road area)
- **Current tools:** Printed route chart, phone calls to supervisor
- **Pain points:**
  - Gets confused when route changes mid-day
  - No way to report a refused delivery
  - Supervisor calls every 30 minutes asking for status
  - Does not know customer preferences (preferred time, special instructions)
- **Goals:** Complete route efficiently, fewer calls from supervisor, clear daily plan
- **Needs:** Simple mobile interface, one-tap status updates, offline capability

### 3. Deepa — Operations Supervisor
- **Age:** 28-45
- **Role:** Manages 5 drivers, handles customer complaints, plans routes
- **Current tools:** Phone calls, WhatsApp, paper records
- **Pain points:**
  - Spends 2 hours every morning manually assigning routes
  - Can not verify if driver reported status is accurate
  - No historical data to resolve customer disputes
  - Adding/removing stops from routes is error-prone
- **Goals:** Automate route planning, approve changes digitally, get analytics
- **Needs:** Dashboard with all routes, approval workflow, route version history

---

## Core Product Features

### MVP (Phase 1-2) — "Get Started"
| Feature | Business Value | Priority |
|---------|---------------|----------|
| Login with role-based access | Security, multi-user | P0 |
| Customer CRUD with map coordinates | Master data foundation | P0 |
| Vehicle and driver management | Master data foundation | P0 |
| Route creation with ordered stops | Core routing capability | P0 |
| Smart stop insertion (cheapest insertion) | Reduces planning time from 30min to 2min | P0 |
| Driver trip execution (start, stops, complete) | Real-time visibility | P0 |
| Stop status tracking (completed/skipped/refused) | Accountability | P0 |
| Admin dashboard with stats | Decision-making | P0 |
| Route map visualization | Visual clarity | P1 |

### Growth (Phase 3) — "Stay in Control"
| Feature | Business Value | Priority |
|---------|---------------|----------|
| Route change approval workflow | Supervisor control without micromanaging | P0 |
| Route version history | Audit trail, dispute resolution | P1 |
| Per-route analytics (completion rate, distance) | Performance management | P1 |
| Driver self-service profile update | Reduces admin overhead | P2 |
| Trip history with stop-level detail | Historical reporting | P1 |
| Bulk customer import (CSV) | Onboarding efficiency | P2 |

### Pro (Phase 4) — "Scale Operations"
| Feature | Business Value | Priority |
|---------|---------------|----------|
| Multi-depot support | Larger distributors | P2 |
| Route optimization (TSP solver) | Fuel cost reduction | P1 |
| Driver location tracking (GPS ping) | Real-time visibility | P1 |
| Customer-facing delivery notifications | Customer satisfaction | P2 |
| Export reports (PDF/Excel) | Compliance, reporting | P2 |
| API access for integrations | ERP/accounting integration | P2 |

---

## Technical Architecture

### System Diagram
```
+-----------------------------------------------------+
|                    CLIENTS                          |
+------------------+----------------------------------+
|   Flutter Web    |   Flutter Mobile (future)        |
|   (Admin Panel)  |   (Driver App, Android/iOS)      |
+--------+---------+--------------+-------------------+
         |                        |
         v                        v
+-----------------------------------------------------+
|              FASTAPI BACKEND (Python)                |
+-----------------------------------------------------+
|  Auth (JWT) | Routes | Trips | Customers | Analytics|
|             |        |       |           |          |
|  Route Optimizer Service (Haversine + Cheapest Insert)|
+------------------------+----------------------------+
                         |
                         v
+-----------------------------------------------------+
|              DATABASE (SQLite to PostgreSQL)         |
+-----------------------------------------------------+
|  users | customers | vehicles | routes | route_stops |
|  trips | trip_stops | route_versions | route_changes|
+-----------------------------------------------------+
```

### Tech Stack
| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Frontend (Admin) | Flutter Web | Single codebase for web + mobile later |
| Frontend (Driver) | Flutter Mobile | Native mobile experience, offline support |
| Backend | FastAPI (Python) | Fast, async, auto-docs, great for APIs |
| Database | SQLite (dev) to PostgreSQL (prod) | Easy dev start, production-ready scaling |
| Maps | Leaflet + OpenStreetMap | Free, no API key needed, good India coverage |
| State Management | Riverpod | Reactive, testable, scalable Flutter state |
| HTTP Client | Dio | interceptors, retry, token refresh |
| Auth | JWT (HS256) | Stateless, simple, works across devices |

### Database Schema (Key Entities)
```
User -------- Route -------- RouteStop -------- Customer
  |              |                |
  |              |-- RouteVersion |
  |              |-- RouteChange  |
  |              |                |
  |              +-- Trip ---- TripStop
  |
  +-- Vehicle
```

---

## Build Phases and Milestones

### Phase 1: Backend Hardening (Week 1)
**Goal:** Production-ready API with no critical security or data issues.

| Task | Effort | Outcome |
|------|--------|---------|
| JWT secret to env var | 5 min | Secure token signing |
| Email/password validation | 10 min | Prevent bad data |
| Role/status enum constraints | 10 min | Data integrity |
| Auth checks on trip endpoints | 15 min | Authorization enforced |
| N+1 query fixes | 20 min | 3-5x faster list endpoints |
| Missing schema fields | 15 min | Complete API responses |
| New endpoints (user delete, self-update, trip cancel) | 30 min | Feature parity |
| Business logic (working_days check, distance calc) | 20 min | Correct behavior |
| Pagination on list endpoints | 20 min | Scalable responses |
| Seed data improvements | 15 min | Realistic demo data |

**Milestone:** All CRUD endpoints validated, seed data populates correctly.

### Phase 2: Flutter Foundation (Week 1-2)
**Goal:** Working login + admin dashboard with map overview.

| Task | Effort | Outcome |
|------|--------|---------|
| Flutter project setup + dependencies | 20 min | Project scaffolded |
| Theme, colors, typography | 15 min | Consistent design system |
| API client with Dio + auth interceptor | 20 min | Token management, error handling |
| Login screen | 15 min | JWT authentication flow |
| Dashboard screen with stats cards | 20 min | At-a-glance overview |
| Route list + detail with map | 30 min | Core route visualization |
| Customer list + create/edit | 20 min | Master data management |
| Vehicle and driver management | 20 min | Fleet management |

**Milestone:** Admin can log in, see dashboard, manage routes/customers/vehicles.

### Phase 3: Route Intelligence (Week 2)
**Goal:** Smart insertion, approval workflow, version history.

| Task | Effort | Outcome |
|------|--------|---------|
| Smart insertion UI (map preview + options) | 30 min | One-tap optimal stop placement |
| Stop reorder (drag and drop) | 20 min | Manual route adjustment |
| Approval workflow screen | 25 min | Supervisor approves/rejects changes |
| Route version history timeline | 20 min | Audit trail |
| Route analytics screen | 20 min | Performance metrics per route |

**Milestone:** Full route management lifecycle.

### Phase 4: Driver Experience (Week 2-3)
**Goal:** Driver can execute trips, update stops, view history.

| Task | Effort | Outcome |
|------|--------|---------|
| Driver home screen (today's route + map) | 25 min | Daily plan at a glance |
| Trip start flow | 15 min | One-tap trip initiation |
| Stop execution (arrive, complete/skip/refuse) | 30 min | Real-time status tracking |
| Progress indicator | 10 min | Visual completion tracking |
| Trip history screen | 20 min | Past trip review |
| Driver profile + vehicle info | 10 min | Self-service |

**Milestone:** Driver can complete full delivery workflow.

### Phase 5: Polish and Production (Week 3)
**Goal:** Error handling, loading states, responsive design, deployment.

| Task | Effort | Outcome |
|------|--------|---------|
| Loading states and skeleton screens | 20 min | Smooth UX |
| Error handling and retry logic | 15 min | Graceful failures |
| Empty states | 10 min | Helpful when no data |
| Responsive layout (desktop + tablet) | 25 min | Multi-device support |
| Offline indicator | 10 min | Network awareness |
| PostgreSQL migration | 15 min | Production database |
| Environment config (.env) | 10 min | Deployment readiness |
| Final testing across all flows | 30 min | Quality assurance |

**Milestone:** Production-ready application deployable to any cloud provider.

---

## Deployment Strategy

### Development
- Backend: `uvicorn main:app --reload` on localhost:8000
- Frontend: `flutter run -d chrome` on localhost:8080
- Database: SQLite file (route_app.db)

### Production
| Component | Service | Cost (est.) |
|-----------|---------|-------------|
| Backend API | Railway / Render / Fly.io | Rs.500-2,000/month |
| PostgreSQL | Supabase / Neon / Railway | Rs.0-1,000/month |
| Flutter Web | Vercel / Cloudflare Pages | Free tier |
| Maps | OpenStreetMap (self-hosted tiles or CDN) | Free |
| Domain + SSL | Cloudflare | Free-Rs.500/month |
| **Total** | | **Rs.500-3,500/month** |

### Multi-Tenancy Strategy (Future)
- Each distributor is a "tenant" with isolated data
- Schema-based isolation (PostgreSQL schemas) or row-level security
- Tenant ID on every table
- Admin panel per tenant, super-admin panel for platform ops

---

## Competitive Landscape

| Competitor | Price | Weakness | Our Advantage |
|-----------|-------|----------|--------------|
| Locus.sh | Rs.15,000+/mo | Enterprise-only, complex | Simple, affordable, SMB-focused |
| FarEye | Rs.20,000+/mo | Logistics companies only | Distribution-specific UX |
| Route4Me | $40+/mo | US-focused, no India maps | India-first, local maps |
| Manual (WhatsApp/Excel) | Free | No analytics, no accountability | Full visibility, zero friction |

**Our positioning:** The simplest, most affordable route management tool for Indian distributors. Not an enterprise logistics platform — a focused tool for the 5-route, 35-customer distributor who wants to stop using WhatsApp.

---

## Success Metrics (First 6 Months)

| Metric | Target |
|--------|--------|
| Registered distributors | 50 |
| Active monthly users | 150 |
| MRR | Rs.1,00,000 |
| Average routes per customer | 4.2 |
| Driver app daily active rate | 80% |
| Customer retention (monthly) | 85% |
| NPS score | >40 |

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Drivers refuse to use app | High | Keep it simpler than WhatsApp, 2 taps max |
| Poor internet in rural areas | Medium | Offline mode: cache route, sync when online |
| Customers want WhatsApp updates | Low | Add customer notification feature in Phase 4 |
| Competitor copies features | Medium | First-mover advantage in SMB India segment |
| Scaling beyond SQLite | Medium | PostgreSQL migration planned in Phase 5 |

---

## Appendix: Complete API Endpoints (Post-Phase 1)

### Auth
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /auth/login | None | Login, get JWT + user |

### Users
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /users/ | Admin | List all users |
| POST | /users/ | Admin | Create user |
| GET | /users/me | Any | Get own profile |
| PUT | /users/me | Any | Update own profile |
| PUT | /users/me/password | Any | Change own password |
| GET | /users/{id} | Any | Get user by ID |
| PUT | /users/{id} | Admin | Update user |
| DELETE | /users/{id} | Admin | Deactivate user |

### Customers
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /customers/ | Any | List customers (search, filter) |
| POST | /customers/ | Admin | Create customer |
| GET | /customers/{id} | Any | Get customer |
| PUT | /customers/{id} | Any | Update customer |
| DELETE | /customers/{id} | Admin | Deactivate customer |

### Vehicles
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /vehicles/ | Any | List vehicles |
| POST | /vehicles/ | Admin | Create vehicle |
| GET | /vehicles/{id} | Any | Get vehicle |
| PUT | /vehicles/{id} | Admin | Update vehicle |
| DELETE | /vehicles/{id} | Admin | Deactivate vehicle |

### Routes
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /routes/ | Any | List routes (driver sees own) |
| POST | /routes/ | Admin | Create route |
| GET | /routes/{id} | Any | Get route with stops |
| PUT | /routes/{id} | Admin | Update route |
| POST | /routes/{id}/stops | Any | Add stop (smart insert) |
| PUT | /routes/{id}/stops/reorder | Any | Reorder stops |
| DELETE | /routes/{id}/stops/{sid} | Admin | Remove stop |
| POST | /routes/{id}/calculate-insertion | Any | Preview insertion options |
| GET | /routes/{id}/versions | Any | Version history |
| GET | /routes/changes/ | Any | List all changes |
| GET | /routes/changes/mine | Driver | My change requests |
| GET | /routes/changes/pending | Admin | Pending approvals |
| POST | /routes/changes/ | Any | Submit change request |
| PUT | /routes/changes/{id}/approve | Admin | Approve + apply |
| PUT | /routes/changes/{id}/reject | Admin | Reject change |

### Trips
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /trips/ | Any | List trips (driver sees own) |
| POST | /trips/ | Any | Start trip |
| GET | /trips/{id} | Any | Get trip with stops |
| PUT | /trips/{id}/stops/{sid} | Driver (owner) | Update stop status |
| PUT | /trips/{id}/complete | Driver (owner) | Complete trip |
| PUT | /trips/{id}/cancel | Driver (owner) | Cancel trip |

### Analytics
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /analytics/dashboard | Any | Dashboard stats |
| GET | /analytics/routes/{id} | Any | Route analytics |
