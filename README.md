# CafeOS ☕

iOS inventory and order management app for café managers.  
Built with SwiftUI + Firebase + Google Gemini Flash 2.0.

**Platform:** iOS 16.4+  
**Architecture:** MVVM  
**Language:** Swift 5.9  

---

## Features

- **Inventory** — Real-time CRUD via Firestore snapshot listener. Low-stock badge, category + unit tracking, supplier linking.
- **Suppliers** — Track contact info, outstanding balances, delivery lead times. Auto-synced with orders via Firestore `arrayUnion`.
- **Orders** — Full order lifecycle (pending → received / cancelled). Mark Received uses a Firestore transaction to prevent double inventory increment on double-tap.
- **Dashboard** — Live summary: total items, low-stock count, pending orders, total amount owed. AI Reorder Advisor card.
- **AI Reorder Advisor** — Sends low-stock items to Google Gemini Flash 2.0. Returns structured JSON (`{ "recommendations": [...] }`). Rendered as urgency-sorted cards — not a text paragraph.
- **Proactive Notifications** — `UNCalendarNotificationTrigger` fires at 8 AM daily when any item is below its threshold. Scheduled automatically when inventory changes — no user action required.
- **URL Extractor** — Paste any job listing URL. Jina.ai Reader API fetches and extracts the content, bypassing scraper blocks on LinkedIn, Indeed, Naukri.
- **Firebase Auth** — Email/password login and sign-up. AppState listens to auth changes and routes the app automatically — no blank screen on launch.

---

## Setup

### 1. Clone

```bash
git clone https://github.com/harisharen222/CafeOS.git
cd CafeOS
open CafeOS.xcodeproj
```

### 2. API Keys

```bash
cp CafeOS/Utilities/Secrets.example.swift CafeOS/Utilities/Secrets.swift
```

Open `Secrets.swift` and fill in your keys:

```swift
enum Secrets {
    static let openAIKey  = "sk-proj-..."   // platform.openai.com/api-keys
    static let jinaAPIKey = "jina_..."      // jina.ai (free tier — optional but recommended)
}
```

> `Secrets.swift` is gitignored and will never be committed. `Secrets.example.swift` is the committed template.

### 3. Firebase

1. Go to [console.firebase.google.com](https://console.firebase.google.com) → New Project → **CafeOS**
2. Add an iOS app → Bundle ID: `HariSharen.CafeOS`
3. Download `GoogleService-Info.plist` → drag into Xcode project root → **add to TARGETS**
4. In Firebase Console:
   - **Firestore Database** → Create Database → Start in test mode
   - **Authentication** → Sign-in Method → Email/Password → Enable
5. Set Firestore security rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4. Run

Select an iOS 16+ simulator → press Run (⌘R).

---

## Architecture

```
MVVM — strict layer separation:

Models/          Pure Codable structs. No logic. @DocumentID exception is intentional.
Services/        All Firebase + API calls. Returns models, throws AppError. No UI imports.
ViewModels/      ObservableObject + @Published. Calls services. No Firebase. No SwiftUI.
Views/           Reads ViewModel state. No Firebase. No business logic.
```

Key decisions:
- **Firestore snapshot listener** on Inventory only — real-time updates where it matters most
- **One-time fetch** on Suppliers and Orders — avoids unnecessary listener overhead
- **Firestore transaction** on Mark Order Received — idempotent, prevents double inventory increment
- **`arrayUnion`** on Supplier.itemsSupplied when an order is created — no duplicates
- All ViewModels injected via `.environmentObject()` from app root — never instantiated in child views

---

## URL Scraper — Approach & Rationale

### The Problem

Job platforms (LinkedIn, Indeed, Naukri) actively block automated scraping:
- **LinkedIn** returns HTTP 999 (custom bot-detection code) or redirects to login
- **Indeed** returns HTTP 403 or renders content via JavaScript that `URLSession` never sees
- **Naukri** rate-limits and blocks non-browser User-Agents

### Approaches Tried

| Approach | Result | Why |
|----------|--------|-----|
| Raw `URLSession` GET | ❌ Failed | HTTP 403 / 999. No User-Agent = instant block. |
| `URLSession` + browser User-Agent | ⚠️ Partial | Passes some bot checks but JS-rendered content is still missing. |
| `WKWebView` in-app | ✅ Works | Renders JS. But requires a full UI component and is slow (~4–6s load). Complex to extract clean text from DOM. |
| `SFSafariViewController` | ❌ View only | Opens the page but gives zero DOM access — no text extraction possible. |
| Firebase Cloud Function proxy | ✅ Works | Server-side headless browser. More robust but significant infrastructure overhead for a demo. |
| **Jina.ai Reader API** | ✅ Works | Free. Server-side fetch returns clean markdown. One line of code. No infrastructure. |

### Chosen Approach: Jina.ai

Prepend `https://r.jina.ai/` to any URL. Jina's servers fetch the page with a real browser, extract the meaningful content, and return clean markdown over a simple HTTP GET.

```
https://r.jina.ai/https://www.indeed.com/viewjob?jk=abc123
```

**Tested:**  
✅ Indeed — works reliably  
✅ Naukri — works reliably  
⚠️ LinkedIn — works sometimes (depends on login state and listing visibility)

**Trade-offs:**
- Free tier: rate-limited (20 requests/min without key, 200/min with free key)
- Jina is a third-party service — if it goes down, the feature fails
- Content quality varies by site — some return full descriptions, some return partial

In a production app: use a Firebase Cloud Function with a headless Chromium instance (Puppeteer) for reliability. For this demo, Jina is the right call — fast to implement, clearly demonstrates the engineering thinking, and works on the most common job boards.

---

## Commit History

18 commits across 3 days — each representing a real working increment.

See `git log --oneline` for the full history.

---

## Notes for Reviewers

- `Secrets.swift` is gitignored — copy from `Secrets.example.swift` and add your keys
- `GoogleService-Info.plist` is gitignored — download from your Firebase project
- Orders are one-item-per-order (intentional simplification). In production: order line-items sub-collection
- `@DocumentID` in models requires `import FirebaseFirestoreSwift` — this is the one intentional exception to the "no Firebase in models" rule
- The AI prompt requests `{ "recommendations": [...] }` (not a bare array) to comply with OpenAI's `json_object` response format requirement (and Google Gemini Flash 2.0).
