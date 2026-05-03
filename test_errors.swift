import Foundation

enum AppError: LocalizedError {
    case aiServiceFailed
    var errorDescription: String? { "AI advisor unavailable." }
}

let error: Error = AppError.aiServiceFailed
print(error.localizedDescription)
