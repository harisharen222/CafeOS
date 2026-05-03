# CafeOS

A take-home assignment project — an iOS app for managing a fictional café's day-to-day operations. Built with SwiftUI and Firebase.

---

## What this is

The idea was to build something a café manager could actually use — tracking inventory, keeping supplier info in one place, and managing purchase orders without juggling spreadsheets. Nothing too complex, just a clean app that covers the basics and doesn't get in the way.

---

## Features

- Add, edit, delete, and view inventory items with quantity and unit tracking
- Supplier management — store contact info, link suppliers to items
- Order management — create orders, assign items and suppliers, mark status
- Dashboard with a quick health check on stock levels
- AI-powered reorder advisor that flags items running low and suggests what to reorder
- URL extractor tool that tries to pull job description content from a pasted link and lets you export it as a PDF

---

## The AI reorder thing

This was one of the more interesting parts to build. The app sends your current inventory data to Google Gemini and asks it to identify items that are low or likely to run out soon, along with a suggested reorder quantity. It shows up on the dashboard and in a dedicated screen.

It's genuinely useful — instead of eyeballing every item, you just get a list of what needs attention. The model is surprisingly good at picking up on obvious patterns like "you have 2kg of coffee beans left and you usually stock 10kg."

---

## Data storage

Everything is stored in Firebase Firestore in real time. Auth is handled by Firebase Authentication — the app supports email/password signup and login. Data is tied to the logged-in user so different accounts stay separate.

No local caching, no offline support — it's all live. For a take-home assignment that felt like the right call, though it would be one of the first things to add if this were a real product.

---

## The URL extractor and why it was painful

This one took more time than expected.

The idea was simple — paste a job listing URL, pull out the relevant content, export a clean PDF. The execution was not as simple.

The first attempt was just a plain URLSession fetch. That obviously doesn't work for LinkedIn because it redirects you to a login page if you're not authenticated. After trying a few things, the approach that actually worked was spoofing browser headers on the request — setting a realistic User-Agent, Accept headers, Accept-Language, the works. If that still returns raw HTML instead of readable content, it falls back to the Jina Reader API, which handles the page rendering server-side and returns the content as markdown. That two-step fetch is Layer 1.

Even after getting readable content, the result was still a mess. A LinkedIn page returned by Jina is hundreds of lines — mostly navigation, sign-in modals, "people also viewed" sections, language selector links, sidebar metadata about job function and industry type. The actual job description is buried somewhere in the middle. So the next step was figuring out where the real content starts and ends.

Layer 2 handles that. It does a few things in order: first it scans for LinkedIn's sign-in modal footer (the "by clicking continue to join or sign in" line) and discards everything up to and including that line, since the modal always appears before the job content. Then it looks for a stop marker like "similar jobs" or "people also viewed" to find the end. For the start of the actual job content, it tries three signals in order — looking for the second H1/H2 heading in the page (the first is usually the page title echo), then looking for the first long prose line that isn't a link or a heading, and finally falling back to known section anchors like "about the role" or "job description". Whatever slice of text is between those two boundaries is what gets passed forward.

Layer 3 is just cleanup. By now the content is in the right region, but it still has markdown formatting artifacts — `**bold**` markers, `[text](url)` link syntax, image tags, tracking URLs, HR dividers made of dashes. This layer strips all of that out line by line and collapses excess blank lines, so what comes out is plain readable text.

Layer 4 takes that clean text and turns it into a structured object — a `JobDescription` with separate fields for title, company, location, employment type, about the role, responsibilities, and requirements. It runs a single pass through the lines using a simple state machine: once it hits a line that looks like a section header (short, not a bullet, matches known phrases like "responsibilities" or "qualifications"), it switches state and starts appending lines to the right bucket. Bullet lines in responsibilities and requirements go into arrays; everything else goes into the about section. There's also a bunch of skip rules for noise that makes it through anyway — LinkedIn metadata bullets like "Seniority level", Naukri sidebar fields like "Role:" and "Industry type:", sign-in CTA lines like "Join to apply", and single-character degree abbreviations that Naukri sometimes splits across lines.

The result gets displayed in the app as a clean structured view, and the same object gets passed directly to the PDF generator — so what you see on screen and what ends up in the PDF are always in sync.

What works: LinkedIn and Naukri job listings come through pretty well. Job title, company, location, responsibilities, and requirements are usually extracted correctly.

What doesn't always work: sites that render job content entirely with JavaScript (the Jina fallback helps but isn't perfect), and pages that aggressively fingerprint API requests. For those, the extractor either returns partial content or nothing useful. Also some Naukri pages format their content in ways the state machine doesn't handle cleanly, so the section boundaries can be off.

Honestly the window detection logic in Layer 2 is the most fragile part. It works for the sites I tested, but it'd probably need adjustments for any site that structures its pages differently.


---

## How to run it

1. Clone the repo
2. Open `CafeOS.xcodeproj` in Xcode
3. Copy `Secrets.example.swift` to `Secrets.swift` and fill in your API keys:
   - A Google Gemini API key (from aistudio.google.com)
   - A Jina API key (from jina.ai — free tier works fine)
4. Make sure you have a Firebase project set up and have added the `GoogleService-Info.plist` to the project (this file is gitignored)
5. Run on a simulator or a real device with iOS 17+

The Firebase setup needs Firestore and Authentication enabled in the Firebase console. Email/password sign-in has to be turned on manually under Authentication > Sign-in methods.

---

## What I'd improve with more time

- Offline support — the app currently requires a network connection for everything
- The URL extractor logic is a bit messy, a proper headless browser approach would be cleaner
- Better error messages when extraction fails — right now it's just a generic alert
- The PDF output is functional but not particularly pretty
- Push notifications for low stock would make the reorder advisor actually actionable
- The dashboard stats could be more detailed — right now it's just a count, not trends over time
