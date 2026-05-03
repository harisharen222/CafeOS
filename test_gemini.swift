import Foundation

let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

// Load secrets from file
let secretsContent = try String(contentsOfFile: "CafeOS/Utilities/Secrets.example.swift")
// But wait, the user's Secrets.swift is untracked. Let's just find the API key.
