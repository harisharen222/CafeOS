import Foundation

enum Constants {
    enum Firestore {
        static let inventory = "inventory"
        static let suppliers = "suppliers"
        static let orders    = "orders"
    }
    enum Categories {
        static let all = ["Dairy", "Beverages", "Dry Goods", "Packaging", "Cleaning", "Other"]
    }
    enum Units {
        static let all = ["kg", "g", "L", "ml", "pcs", "bags", "boxes", "bottles"]
    }
}
