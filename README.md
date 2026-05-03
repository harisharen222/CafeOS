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

Most job sites (LinkedIn especially) block straightforward fetch requests. The page returns either a login wall or a redirect. So the approach ended up being a two-step thing: first try a direct GET with browser-like headers, and if that returns HTML instead of readable content, fall back to the Jina Reader API which handles the rendering and returns cleaner markdown.

Even after getting the content, the extracted text was full of noise — navigation links, sign-in modals, language selectors, sidebar metadata from the site's own UI. A lot of that had to be filtered out manually, line by line, which is kind of fragile but it works well enough for LinkedIn and Naukri listings.

What works: job titles, company names, responsibilities, requirements — they come through reasonably clean for most listings.

What doesn't always work: very dynamic pages that require JavaScript to render the actual job content, and sites that actively fingerprint requests. For those, the extractor either returns partial content or nothing useful.

Honestly the filtering logic is the part I'd most want to rewrite if I had more time.

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
