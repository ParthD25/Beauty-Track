# Beauty Track

Beauty Track is a professional-grade inventory and expense platform built for salons that live in iOS. The app combines SwiftUI, SwiftData, and VisionKit so owners can scan receipts, reconcile stock, and get reorder recommendations without leaving their phone.

## Highlights
- **Live Dashboard** – KPIs for stock value, low inventory alerts, spending pace, and recent activity cards with one-tap shortcuts to scan, log usage, or run reorder analysis.
- **Deep Inventory Tools** – Smart search across names/SKUs/categories, inline stock editing, color-coded availability, category filters, multi-sort views, and over 100 sample products to explore.
- **Reorder Intelligence** – Usage-rate based urgency scoring (critical/high/medium), automated quantity suggestions, supplier price comparisons, and consumption charts.
- **Receipt Automation** – VisionKit-powered OCR, salon-specific item heuristics, confidence scoring, multi-pack detection, “did you mean?” matches, and manual fallback entry with the same reconciliation flow.
- **Multi-Location Awareness** – Independent counts per salon plus combined analytics, fast location switching, and transfer tracking.
- **Configurable Settings** – Business profile, notification preferences, automation defaults, CSV export, and fully local privacy controls.

## Feature Deep Dive
### Dashboard & Analytics
- Real-time metrics for product count, low stock, monthly spend, and stock efficiency.
- Activity timeline covering receipt imports, usage logs, and alerts.
- Interactive charts showing spend by supplier/category and usage trends.

### Inventory Management
- Dual-result smart search (exact + fuzzy) with Combine-powered live updates.
- Visual stock indicator (critical/low/healthy) plus preset adjustment buttons.
- Filters for category, supplier, location, and sort toggles (name, stock, updated).

### Receipt Processing
- Camera, photo library, document picker, and VisionKit enhancement pipeline.
- Automatic matching to existing products, new product creation, expense logging, and pack-size handling.
- Manual Receipt Entry sheet mirrors the automated import path with structured fields.

### Reorder Recommendations
- Moving-average usage calculation, days-until-empty projections, and urgency tagging.
- Vendor history, price comparisons, and suggested quantities based on consumption.

### Multi-Location Support
- Manage multiple salons (e.g., Downtown, Westside) with isolated stock plus consolidated reports.
- Track transfers and keep location context when scanning receipts or logging usage.

### Settings & Administration
- Business profile, notification preferences, automation defaults, export tools, and privacy controls.
- Optional sample data seeding for demos.

## Technical Stack
- **SwiftUI** for the entire interface (iOS 17+).
- **SwiftData** for local persistence (with optional iCloud sync in production builds).
- **VisionKit + Vision** for OCR, auto-cropping, and enhancement.
- **Charts** and **Combine** for analytics and reactive flows.

### Core Models
- `Product` – Stock tracking, reorder signals, cost, and categorization.
- `Expense` – Receipt-derived or manual expense logging.
- `ReceiptItem`, `ParsedReceiptItem`, `ParsedReceipt` – OCR pipeline structures.
- `Category`, `Supplier`, `UsageRecord`, and `InventoryManager` for business logic.

### Key Algorithms
- Usage-rate moving averages for reorder urgency.
- Heuristic + fuzzy matching for receipt item identification.
- Confidence-scored OCR with salon-specific keyword filtering and normalization.

## Privacy, Security & Data Ownership
- Local-first architecture: all data lives on device; no third-party servers.
- iOS-level encryption plus optional iCloud backup (user-controlled).
- No tracking, analytics, or ad SDKs. Full CSV export and data deletion tools.

## Requirements & Setup
- iOS 17.0+.
- iPhone or iPad with camera access.
- Minimum ~150 MB free space.
- Build with Xcode 15+; run `xcodebuild -project BeautyTrack/BeautyTrack.xcodeproj -scheme BeautyTrack -destination 'platform=iOS Simulator,name=iPhone 17' build`.

## Usage Workflow
1. **Morning review** – check dashboard alerts and reorder list.
2. **Receiving** – scan receipts or use manual entry as shipments arrive.
3. **Daily operations** – log usage per service/location to keep stock accurate.
4. **Weekly** – review analytics, export summaries, plan orders, and reconcile inventory.

## Support & Policies
- In-app Help Center with tutorials, Privacy Policy, and Terms of Service.
- Contact: `support@beautytrack.app` (placeholder) or business phone M–F, 9a–5p PST.
- Complies with CCPA/GDPR principles and Apple App Store guidelines.

## Roadmap
1. **v1.1** – Barcode scanning + advanced reporting widgets.
2. **v1.2** – Team access with roles and audit trails.
3. **v1.3** – Supplier integrations and third-party API hooks.
4. **v2.0** – Predictive analytics and AI-powered forecasting.

## Licensing
Beauty Track is commercial software. A single license covers all salon locations you operate; resale is prohibited. All business data remains yours, and exports are unlimited.

> Beauty Track – professional salon inventory, automated with intelligence.
