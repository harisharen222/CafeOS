#if DEBUG
import Foundation

/// Call SeedData.populate() once from a debug button or from CafeOSApp's init in DEBUG builds.
/// Delete this file before production.
enum SeedData {
    static func populate(firestoreService: FirestoreService) async {
        let suppliers = [
            Supplier(name: "Fresh Dairy Co", contactName: "Ramesh Kumar",
                     phone: "9876543210", email: "ramesh@freshdairy.in",
                     amountOwed: 4500, deliveryDays: 1,
                     itemsSupplied: []),
            Supplier(name: "Beans & Brews", contactName: "Priya Nair",
                     phone: "9123456780", email: "priya@beansbrews.in",
                     amountOwed: 12000, deliveryDays: 3,
                     itemsSupplied: []),
            Supplier(name: "PaperPack India", contactName: "Arjun Mehta",
                     phone: "9988776655", email: "arjun@paperpack.in",
                     amountOwed: 2200, deliveryDays: 2,
                     itemsSupplied: [])
        ]

        for supplier in suppliers {
            do {
                try await firestoreService.add(supplier, to: "suppliers")
            } catch { }
        }

        // Fetch back to get IDs
        // For demo: hardcode items without supplier linking for speed
        let items = [
            InventoryItem(name: "Oat Milk", category: "Dairy",
                          quantity: 2, unit: "L",
                          minimumThreshold: 10, costPerUnit: 85),
            InventoryItem(name: "Espresso Beans", category: "Beverages",
                          quantity: 0.5, unit: "kg",
                          minimumThreshold: 5, costPerUnit: 1200),
            InventoryItem(name: "Paper Cups (12oz)", category: "Packaging",
                          quantity: 45, unit: "pcs",
                          minimumThreshold: 200, costPerUnit: 4),
            InventoryItem(name: "Whole Milk", category: "Dairy",
                          quantity: 8, unit: "L",
                          minimumThreshold: 15, costPerUnit: 65),
            InventoryItem(name: "Brown Sugar", category: "Dry Goods",
                          quantity: 1.2, unit: "kg",
                          minimumThreshold: 3, costPerUnit: 90),
            InventoryItem(name: "Vanilla Syrup", category: "Beverages",
                          quantity: 3, unit: "bottles",
                          minimumThreshold: 2, costPerUnit: 350),
            InventoryItem(name: "Cleaning Tablets", category: "Cleaning",
                          quantity: 5, unit: "pcs",
                          minimumThreshold: 10, costPerUnit: 120)
        ]

        for item in items {
            do {
                try await firestoreService.add(item, to: "inventory")
            } catch { }
        }
    }
}
#endif
