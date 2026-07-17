import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import SwiftUI

// Models mapped to Firestore
struct FirebaseChatRoom: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var isSpace: Bool
    var lastMessage: String
    var updatedAt: Date
    var type: String? // "direct", "group", "bot", "space"
    var memberIds: [String]?
    var typing: [String: Bool]? // [userId: isTyping]
    var callStatus: CallModel?
    var lastMessageSenderId: String? // Added for notifications
}

struct CallModel: Codable, Equatable {
    var status: String // "ringing", "accepted", "ended"
    var callerId: String
    var callerName: String
    var isVideo: Bool
    var channelName: String
}

struct FirebaseChatMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var roomId: String
    var senderId: String
    var text: String
    var imageUrl: String?
    var audioUrl: String?
    var locationLat: Double?
    var locationLng: Double?
    var replyToId: String?
    var reactions: [String: String]? // [userId: emoji]
    var timestamp: Date
    var status: String // "sent", "delivered", "read"
}

struct FirebaseUser: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var avatarUrl: String?
    var isOnline: Bool
    var lastSeen: Date
}

struct FirebaseCall: Identifiable, Codable {
    @DocumentID var id: String?
    var callerName: String
    var callerId: String
    var type: String // "audio", "video"
    var status: String // "missed", "completed", "declined"
    var timestamp: Date
    var duration: TimeInterval? // in seconds
}

// Default room ID dari Firestore (General room)
let defaultRoomId = "Zk7kzZY8DXLZOPgDt3Qj"

// Global Manager
class FirebaseManager: ObservableObject, @unchecked Sendable {
    static let shared = FirebaseManager()
    
    private let db = Firestore.firestore()
    private var messagesListener: ListenerRegistration?
    
    @Published var chatRooms: [FirebaseChatRoom] = []
    @Published var currentMessages: [FirebaseChatMessage] = []
    @Published var calls: [FirebaseCall] = []
    @Published var users: [FirebaseUser] = []
    
    // Hapus semua data mock/lama dari Firestore (hanya digunakan sekali)
    func deleteAllMockData(completion: @escaping () -> Void) {
        Task {
            do {
                // Hapus semua rooms
                let roomsSnapshot = try await db.collection("rooms").getDocuments()
                let roomsBatch = db.batch()
                for doc in roomsSnapshot.documents {
                    roomsBatch.deleteDocument(doc.reference)
                }
                try await roomsBatch.commit()
                
                // Hapus semua messages
                let msgsSnapshot = try await db.collection("messages").getDocuments()
                let msgsBatch = db.batch()
                for doc in msgsSnapshot.documents {
                    msgsBatch.deleteDocument(doc.reference)
                }
                try await msgsBatch.commit()
                
                print("✅ Semua data mock berhasil dihapus dari Firestore")
                await MainActor.run { completion() }
            } catch {
                print("❌ Gagal hapus data mock: \(error.localizedDescription)")
                await MainActor.run { completion() }
            }
        }
    }
    
    // Update Typing Status
    @MainActor
    func setTypingStatus(roomId: String, isTyping: Bool) {
        guard let currentUserId = AuthManager.shared.currentUser?.uid else { return }
        // Use dot notation to only update the specific user's typing status
        db.collection("rooms").document(roomId).updateData([
            "typing.\(currentUserId)": isTyping
        ]) { [weak self] error in
            guard let self = self else { return }
            if error != nil {
                // If the document doesn't have a typing field at all yet, updateData on a nested field might fail,
                // so we fallback to setData with merge if needed.
                self.db.collection("rooms").document(roomId).setData([
                    "typing": [currentUserId: isTyping]
                ], merge: true)
            }
        }
    }
    
    // MARK: - Call Management
    func initiateCall(roomId: String, callerId: String, callerName: String, isVideo: Bool, channelName: String) {
        let callData: [String: Any] = [
            "status": "ringing",
            "callerId": callerId,
            "callerName": callerName,
            "isVideo": isVideo,
            "channelName": channelName
        ]
        db.collection("rooms").document(roomId).setData(["callStatus": callData], merge: true)
    }
    
    func updateCallStatus(roomId: String, status: String) {
        db.collection("rooms").document(roomId).updateData([
            "callStatus.status": status
        ])
    }
    
    func endCall(roomId: String) {
        db.collection("rooms").document(roomId).updateData([
            "callStatus": FieldValue.delete()
        ])
    }
    
    // Seed initial data jika Firestore kosong (dinonaktifkan)
    func seedInitialDataIfNeeded() {
        // Fungsi ini dinonaktifkan — tidak membuat mock data lagi
    }

    // Listen to all chat rooms
    func listenToChatRooms() {
        db.collection("rooms").order(by: "updatedAt", descending: true)
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching rooms: \(String(describing: error))")
                    return
                }
                
                self.chatRooms = documents.compactMap { doc -> FirebaseChatRoom? in
                    try? doc.data(as: FirebaseChatRoom.self)
                }
                
                // Trigger local notification if a new message arrives from someone else
                for change in querySnapshot!.documentChanges {
                    if change.type == .modified {
                        if let room = try? change.document.data(as: FirebaseChatRoom.self) {
                            if let senderId = room.lastMessageSenderId, senderId != Auth.auth().currentUser?.uid {
                                NotificationManager.shared.scheduleLocalNotification(
                                    title: room.name,
                                    body: room.lastMessage,
                                    roomId: room.id ?? ""
                                )
                            }
                        }
                    }
                }
            }
    }
    
    // Listen to users
    func listenToUsers() {
        db.collection("users")
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching users: \(String(describing: error))")
                    return
                }
                
                self.users = documents.compactMap { doc -> FirebaseUser? in
                    try? doc.data(as: FirebaseUser.self)
                }
            }
    }
    
    // Sync authenticated user profile to Firestore
    func syncUserProfile(user: User) {
        let email = user.email ?? ""
        let name = user.displayName ?? (email.components(separatedBy: "@").first ?? "User")
        
        let userData: [String: Any] = [
            "name": name,
            "email": email,
            "isOnline": true,
            "lastSeen": Timestamp(date: Date())
        ]
        
        db.collection("users").document(user.uid).setData(userData, merge: true) { error in
            if let error = error {
                print("Error syncing user profile: \(error)")
            }
        }
    }

    // Listen to calls
    func listenToCalls() {
        db.collection("calls").order(by: "timestamp", descending: true)
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching calls: \(String(describing: error))")
                    return
                }
                
                self.calls = documents.compactMap { doc -> FirebaseCall? in
                    try? doc.data(as: FirebaseCall.self)
                }
            }
    }
    
    // Listen to messages for a specific room
    func listenToMessages(roomId: String) {
        messagesListener?.remove()
        self.currentMessages = []
        
        var isInitialLoad = true
        
        messagesListener = db.collection("messages")
            .whereField("roomId", isEqualTo: roomId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching messages: \(String(describing: error))")
                    return
                }
                
                // Sort client-side to avoid needing a composite Firestore index
                self.currentMessages = documents.compactMap { doc -> FirebaseChatMessage? in
                    try? doc.data(as: FirebaseChatMessage.self)
                }.sorted { $0.timestamp < $1.timestamp }
                
                if !isInitialLoad {
                    for change in querySnapshot!.documentChanges {
                        if change.type == .added {
                            if let message = try? change.document.data(as: FirebaseChatMessage.self) {
                                if message.senderId != Auth.auth().currentUser?.uid {
                                    // Play in-app sound for incoming message while inside chat
                                    NotificationManager.shared.playInAppSound()
                                }
                            }
                        }
                    }
                }
                isInitialLoad = false
            }
    }

    func removeMessagesListener() {
        messagesListener?.remove()
        messagesListener = nil
    }
    
    // MARK: - Sending & Modifying Messages
    func sendMessage(roomId: String, text: String, replyToId: String? = nil, imageUrl: String? = nil, audioUrl: String? = nil, locationLat: Double? = nil, locationLng: Double? = nil) {
        Task { @MainActor in
            let senderId = AuthManager.shared.currentUser?.uid ?? "currentUser"
            let message = FirebaseChatMessage(
                roomId: roomId,
                senderId: senderId,
                text: text,
                imageUrl: imageUrl,
                audioUrl: audioUrl,
                locationLat: locationLat,
                locationLng: locationLng,
                replyToId: replyToId,
                reactions: nil,
                timestamp: Date(),
                status: "sent"
            )
            
            do {
                let _ = try db.collection("messages").addDocument(from: message)
                
                // Update the room's last message
                var lastMessageText = text
                if imageUrl != nil { lastMessageText = "📷 Foto" }
                else if audioUrl != nil { lastMessageText = "🎤 Pesan Suara" }
                else if locationLat != nil { lastMessageText = "📍 Lokasi" }
                
                db.collection("rooms").document(roomId).updateData([
                    "lastMessage": lastMessageText,
                    "lastMessageSenderId": senderId,
                    "updatedAt": Timestamp(date: Date())
                ])
                
            } catch {
                print("Error writing message to Firestore: \(error)")
            }
        }
    }
    
    // Delete a message
    func deleteMessage(messageId: String) {
        Task {
            do {
                try await db.collection("messages").document(messageId).delete()
            } catch {
                print("Error removing message: \(error)")
            }
        }
    }
    
    // Delete multiple messages
    func deleteMessages(messageIds: [String]) {
        Task {
            let batch = db.batch()
            for id in messageIds {
                let ref = db.collection("messages").document(id)
                batch.deleteDocument(ref)
            }
            do {
                try await batch.commit()
            } catch {
                print("Error removing multiple messages: \(error)")
            }
        }
    }
    
    // React to a message
    func reactToMessage(messageId: String, emoji: String) {
        Task { @MainActor in
            let userId = AuthManager.shared.currentUser?.uid ?? "currentUser"
            
            do {
                let document = try await db.collection("messages").document(messageId).getDocument()
                guard document.exists else { return }
                var currentReactions = document.data()?["reactions"] as? [String: String] ?? [:]
                
                // Toggle reaction: if it's the same, remove it, else set it
                if currentReactions[userId] == emoji {
                    currentReactions.removeValue(forKey: userId)
                } else {
                    currentReactions[userId] = emoji
                }
                
                try await document.reference.updateData(["reactions": currentReactions])
            } catch {
                print("Error updating reaction: \(error)")
            }
        }
    }

    // Update user profile in FirebaseAuth & Firestore users collection
    func updateUserProfile(name: String, avatarUrl: String) {
        Task { @MainActor in
            guard let user = AuthManager.shared.currentUser else { return }
            
            // 1. Update Firebase Auth Profile
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            if !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                changeRequest.photoURL = url
            } else {
                changeRequest.photoURL = nil
            }
            
            do {
                try await changeRequest.commitChanges()
                // Force AuthManager to update its UI
                AuthManager.shared.objectWillChange.send()
            } catch {
                print("Error committing profile changes to FirebaseAuth: \(error)")
            }
            
            // 2. Update Firestore users collection
            let userData: [String: Any] = [
                "name": name,
                "avatarUrl": avatarUrl,
                "email": user.email ?? "",
                "isOnline": true,
                "lastSeen": Timestamp(date: Date())
            ]
            
            do {
                try await db.collection("users").document(user.uid).setData(userData, merge: true)
            } catch {
                print("Error writing profile changes to Firestore: \(error)")
            }
        }
    }

    // Create new chat room (direct, group, bot, space)
    func createChatRoom(name: String, isSpace: Bool, type: String, memberIds: [String], completion: @escaping (String) -> Void) {
        Task { @MainActor in
            let roomId: String
            // For 1-to-1 DMs, we use a deterministic roomId based on sorted UIDs to prevent duplicates
            if type == "direct" && memberIds.count == 2 {
                let sortedIds = memberIds.sorted()
                roomId = "direct_\(sortedIds[0])_\(sortedIds[1])"
            } else if type == "bot" {
                let currentUserId = AuthManager.shared.currentUser?.uid ?? "currentUser"
                roomId = "bot_\(currentUserId)"
            } else {
                roomId = UUID().uuidString
            }
            
            let ref = db.collection("rooms").document(roomId)
            
            do {
                // Check if already exists (especially for direct chats)
                let document = try await ref.getDocument()
                if document.exists {
                    completion(roomId)
                    return
                }
                
                let data: [String: Any] = [
                    "name": name,
                    "isSpace": isSpace,
                    "type": type,
                    "memberIds": memberIds,
                    "lastMessage": type == "bot" ? "Hello! Saya Nexus Bot. Ada yang bisa saya bantu?" : "Room baru dibuat",
                    "updatedAt": Timestamp(date: Date())
                ]
                
                try await ref.setData(data)
                
                // If it's a bot, let's also auto-populate a welcome message
                if type == "bot" {
                    let welcomeMsg: [String: Any] = [
                        "roomId": roomId,
                        "text": "Hello! Saya Nexus Bot. Ada yang bisa saya bantu? Silakan ketik pesan untuk mengobrol dengan saya.",
                        "senderId": "nexus-bot",
                        "senderName": "Nexus Bot",
                        "status": "read",
                        "timestamp": Timestamp(date: Date())
                    ]
                    try await db.collection("messages").addDocument(data: welcomeMsg)
                }
                
                completion(roomId)
            } catch {
                print("Error creating chat room: \(error)")
                completion("")
            }
        }
    }
    
    // Delete a chat room and all of its messages
    func deleteChatRoom(roomId: String) {
        Task {
            do {
                // Delete room document
                try await db.collection("rooms").document(roomId).delete()
                
                // Delete all messages in this room
                let messagesSnapshot = try await db.collection("messages")
                    .whereField("roomId", isEqualTo: roomId)
                    .getDocuments()
                
                let batch = db.batch()
                for doc in messagesSnapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
                print("Successfully deleted room \(roomId) and its messages.")
            } catch {
                print("Error deleting chat room: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Firebase Storage Media Uploads
    
    func uploadImage(image: UIImage) async throws -> String {
        // Automatically compress and resize image aggressively to fit within Firestore 1MB document limit
        let targetSize = CGSize(width: 600, height: 600 * (image.size.height / image.size.width))
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.4) else {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        // Return as Base64 data URI
        let base64String = imageData.base64EncodedString()
        return "data:image/jpeg;base64,\(base64String)"
    }
    
    func uploadAudio(fileURL: URL) async throws -> String {
        // Note: Audio should be very short to fit in Firestore. 
        // iOS M4A audio is usually very small (~10KB/s)
        let audioData = try Data(contentsOf: fileURL)
        let base64String = audioData.base64EncodedString()
        return "data:audio/m4a;base64,\(base64String)"
    }
}
