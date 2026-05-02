import Foundation
import FirebaseFirestore

class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: — One-time fetch
    func fetch<T: Codable>(_ collection: String) async throws -> [T] {
        do {
            let snapshot = try await db.collection(collection).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: T.self) }
        } catch {
            throw AppError.firestoreFetchFailed
        }
    }

    // MARK: — Real-time listener (Inventory)
    func listen<T: Codable>(
        _ collection: String,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        db.collection(collection).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else { return }
            let items = documents.compactMap { try? $0.data(as: T.self) }
            DispatchQueue.main.async { onChange(items) }
        }
    }

    // MARK: — Add
    func add<T: Encodable>(_ item: T, to collection: String) async throws {
        do {
            try db.collection(collection).addDocument(from: item)
        } catch {
            throw AppError.firestoreWriteFailed
        }
    }

    // MARK: — Update
    func update<T: Encodable>(_ item: T, id: String, in collection: String) async throws {
        do {
            try db.collection(collection).document(id).setData(from: item)
        } catch {
            throw AppError.firestoreWriteFailed
        }
    }

    // MARK: — Delete
    func delete(id: String, from collection: String) async throws {
        do {
            try await db.collection(collection).document(id).delete()
        } catch {
            throw AppError.firestoreDeleteFailed
        }
    }

    // MARK: — Append itemID to supplier's itemsSupplied (arrayUnion — idempotent)
    func addItemToSupplier(supplierID: String, itemID: String) async throws {
        do {
            try await db.collection(Constants.Firestore.suppliers)
                .document(supplierID)
                .updateData(["itemsSupplied": FieldValue.arrayUnion([itemID])])
        } catch {
            throw AppError.firestoreWriteFailed
        }
    }

    // MARK: — Transaction: Mark Order Received (idempotent — double-tap safe)
    func markOrderReceived(orderID: String, itemID: String, quantity: Double) async throws {
        let orderRef = db.collection(Constants.Firestore.orders).document(orderID)
        let itemRef  = db.collection(Constants.Firestore.inventory).document(itemID)

        do {
            try await db.runTransaction { transaction, errorPointer in
                let orderDoc: DocumentSnapshot
                do {
                    orderDoc = try transaction.getDocument(orderRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                // Idempotency check — if already received or cancelled, do nothing
                guard let currentStatus = orderDoc.data()?["status"] as? String,
                      currentStatus == OrderStatus.pending.rawValue else {
                    return nil
                }

                transaction.updateData([
                    "status": OrderStatus.received.rawValue,
                    "receivedDate": Timestamp(date: Date())
                ], forDocument: orderRef)

                transaction.updateData([
                    "quantity": FieldValue.increment(quantity)
                ], forDocument: itemRef)

                return nil
            }
        } catch {
            throw AppError.transactionFailed
        }
    }
}
