import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let lowStockAlertIdentifier = "com.cafeOS.lowStockAlert"

    // MARK: — Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    // MARK: — Schedule

    /// Schedules or cancels the daily 8 AM low-stock notification.
    /// Safe to call every time inventory changes — uses a fixed identifier so it replaces the previous schedule.
    func scheduleLowStockAlert(for items: [InventoryItem]) {
        // Cancel ONLY our specific notification — do not nuke all notifications
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [lowStockAlertIdentifier])

        guard !items.isEmpty else {
            // No low-stock items — nothing to schedule
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Low Stock Alert ☕"
        content.sound = .default

        if items.count == 1 {
            content.body = "\(items[0].name) is running low — reorder before peak hours."
        } else {
            let names = items.prefix(3).map(\.name).joined(separator: ", ")
            let suffix = items.count > 3 ? " and \(items.count - 3) more" : ""
            content.body = "\(names)\(suffix) are running low."
        }

        // Deep-link target — handled in CafeOSApp's onOpenURL or notification delegate
        content.userInfo = ["deepLink": "reorderAdvisor"]
        content.badge = NSNumber(value: items.count)

        // Trigger: 8:00 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: lowStockAlertIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationService] Failed to schedule: \(error.localizedDescription)")
            }
        }
    }

    // MARK: — Check status (for UI badge on Dashboard)

    func hasPendingLowStockAlert(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let hasPending = requests.contains { $0.identifier == self.lowStockAlertIdentifier }
            DispatchQueue.main.async { completion(hasPending) }
        }
    }
}
