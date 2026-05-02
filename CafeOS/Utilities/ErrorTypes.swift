import Foundation

enum AppError: LocalizedError {
    case firestoreFetchFailed
    case firestoreWriteFailed
    case firestoreDeleteFailed
    case transactionFailed
    case invalidInput(String)
    case networkUnavailable
    case aiServiceFailed
    case urlExtractionFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .firestoreFetchFailed:  return "Failed to load data. Check your connection."
        case .firestoreWriteFailed:  return "Failed to save. Please try again."
        case .firestoreDeleteFailed: return "Failed to delete. Please try again."
        case .transactionFailed:     return "Operation failed. It may have already been completed."
        case .invalidInput(let msg): return msg
        case .networkUnavailable:    return "No internet connection."
        case .aiServiceFailed:       return "AI advisor unavailable. Try again later."
        case .urlExtractionFailed:   return "Could not extract content. Check the URL and retry."
        case .unknown:               return "Something went wrong. Please try again."
        }
    }
}
