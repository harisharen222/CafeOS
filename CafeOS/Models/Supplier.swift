import Foundation
import FirebaseFirestore

struct Supplier: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var contactName: String
    var phone: String
    var email: String
    var amountOwed: Double
    var deliveryDays: Int
    var itemsSupplied: [String]

    init(
        id: String? = nil,
        name: String,
        contactName: String,
        phone: String,
        email: String,
        amountOwed: Double = 0,
        deliveryDays: Int = 3,
        itemsSupplied: [String] = []
    ) {
        self.id = id
        self.name = name
        self.contactName = contactName
        self.phone = phone
        self.email = email
        self.amountOwed = amountOwed
        self.deliveryDays = deliveryDays
        self.itemsSupplied = itemsSupplied
    }
}
