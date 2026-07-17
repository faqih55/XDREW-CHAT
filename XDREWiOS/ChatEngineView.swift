import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Local Message Model
struct Message: Identifiable {
    var id: String
    let text: String
    let isUser: Bool
    var status: MessageStatus
    var timestamp: Date = Date()
    var reactions: [String: String] = [:]
    var replyToId: String?
    var imageUrl: String?
    var audioUrl: String?
    var locationLat: Double?
    var locationLng: Double?
    var senderName: String = "User"
    var senderId: String = ""

    enum MessageStatus {
        case pending, sent, delivered, read
    }
}

// MARK: - Chat Engine View
struct ChatEngineView: View {
    let roomId: String
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var firebaseManager = FirebaseManager.shared
    @AppStorage("app_language") var appLanguage: AppLanguage = .english

    @State private var messageText = ""
    @State private var isTyping = false
    @State private var showAttachments = false
    @State private var isPiPActive = false
    @State private var pipOffset: CGSize = CGSize(width: 100, height: -200)
    @State private var selectedMessageId: String? = nil
    @State private var showReactionFor: String? = nil
    @State private var replyingToMessageId: String? = nil
    @FocusState private var isInputFocused: Bool
    
    // Multi-selection mode
    @State private var isSelectionMode = false
    @State private var selectedMessageIds = Set<String>()
    
    // Typing Timer
    @State private var typingTimer: Timer?
    
    // Voice Note States
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var voiceNoteTimer: Timer?
    @State private var micDragOffset: CGFloat = 0
    
    // Photo Picker State
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showLocationPicker = false
    @State private var isRecordingLocked = false
    @State private var hasCancelledDrag = false
    @StateObject private var audioRecorder = AudioRecorder()
    
    // Call States
    @State private var showCallView = false
    @State private var isVideoCall = false
    @State private var currentChannelName = ""
    @State private var showIncomingCallAlert = false

    var displayMessages: [Message] {
        if firebaseManager.currentMessages.isEmpty {
            if currentChatRoom?.type == "bot" {
                return [
                    Message(id: "welcome-bot-msg", text: "Hello, I am Nexus Bot! How can I help you today? 👋", isUser: false, status: .read, senderName: "Nexus Bot")
                ]
            }
            return []
        }
        return firebaseManager.currentMessages.map { msg in
            let statusEnum: Message.MessageStatus = {
                switch msg.status {
                case "sent": return .sent
                case "delivered": return .delivered
                case "read": return .read
                default: return .pending
                }
            }()
            let currentUserId = AuthManager.shared.currentUser?.uid ?? "currentUser"
            
            // Resolve sender's real name from users list
            let matchedUser = firebaseManager.users.first(where: { $0.id == msg.senderId })
            let name = matchedUser?.name ?? (msg.senderId == "currentUser" || msg.senderId == currentUserId ? "You" : "User")
            
            return Message(
                id: msg.id ?? UUID().uuidString,
                text: msg.text,
                isUser: msg.senderId == "currentUser" || msg.senderId == currentUserId,
                status: statusEnum,
                timestamp: msg.timestamp,
                reactions: msg.reactions ?? [:],
                replyToId: msg.replyToId,
                imageUrl: msg.imageUrl,
                audioUrl: msg.audioUrl,
                locationLat: msg.locationLat,
                locationLng: msg.locationLng,
                senderName: name,
                senderId: msg.senderId
            )
        }
    }

    var currentChatRoom: FirebaseChatRoom? {
        firebaseManager.chatRooms.first(where: { $0.id == roomId })
    }
    
    var directChatTargetUser: FirebaseUser? {
        guard let room = currentChatRoom, room.type == "direct", let members = room.memberIds else { return nil }
        let currentUserId = AuthManager.shared.currentUser?.uid ?? ""
        if let otherUserId = members.first(where: { $0 != currentUserId }) {
            return firebaseManager.users.first(where: { $0.id == otherUserId })
        }
        return nil
    }

    var roomName: String {
        if let targetUser = directChatTargetUser {
            return targetUser.name
        }
        return currentChatRoom?.name ?? "Chat"
    }

    var isOtherUserTyping: Bool {
        guard let typingDict = currentChatRoom?.typing else { return false }
        guard let targetUser = directChatTargetUser else { return false }
        return typingDict[targetUser.id ?? ""] == true
    }

    @ViewBuilder
    private var typingIndicatorSection: some View {
        if isOtherUserTyping {
            TypingIndicatorBubble(userName: directChatTargetUser?.name ?? "User", avatarUrl: directChatTargetUser?.avatarUrl)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .id("typingIndicator")
        }
    }
    
    @ViewBuilder
    private var messageListArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Date separator
                    DateSeparator(label: "Today")
                        .padding(.top, 12)

                    ForEach(displayMessages) { message in
                        MessageBubble(
                            message: message,
                            roomType: currentChatRoom?.type ?? "direct",
                            showReaction: showReactionFor == message.id,
                            repliedMessage: message.replyToId != nil ? displayMessages.first(where: { $0.id == message.replyToId }) : nil,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedMessageIds.contains(message.id),
                            onLongPress: {
                                withAnimation(.spring(response: 0.3)) {
                                    showReactionFor = showReactionFor == message.id ? nil : message.id
                                }
                            },
                            onReact: { emoji in
                                firebaseManager.reactToMessage(messageId: message.id, emoji: emoji)
                                showReactionFor = nil
                            },
                            onReply: {
                                replyingToMessageId = message.id
                                showReactionFor = nil
                                isInputFocused = true
                            },
                            onDelete: {
                                firebaseManager.deleteMessage(messageId: message.id)
                                showReactionFor = nil
                            },
                            onSelect: {
                                if !isSelectionMode {
                                    withAnimation {
                                        isSelectionMode = true
                                    }
                                }
                                if selectedMessageIds.contains(message.id) {
                                    selectedMessageIds.remove(message.id)
                                } else {
                                    selectedMessageIds.insert(message.id)
                                }
                            }
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85, anchor: message.isUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    // Typing indicator
                    typingIndicatorSection

                    Color.clear.frame(height: 80).id("bottom")
                }
                .padding(.horizontal, 12)
            }
            // ✅ Keyboard hilang saat scroll (interaktif)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: displayMessages.count) { _, _ in
                withAnimation(.spring(response: 0.4)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isOtherUserTyping) { _, isTyping in
                if isTyping {
                    withAnimation {
                        proxy.scrollTo("typingIndicator", anchor: .bottom)
                    }
                }
            }
            // ✅ Keyboard hilang saat tap area pesan
            .onTapGesture {
                showReactionFor = nil
                isInputFocused = false
            }
            // ✅ Keyboard hilang saat reaction picker muncul
            .onChange(of: showReactionFor) { _, _ in
                if showReactionFor != nil {
                    isInputFocused = false
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.95, green: 0.94, blue: 0.98).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────
                if isSelectionMode {
                    selectionHeader
                } else {
                    chatHeader
                }

                // ── Message List ─────────────────────────────────────
                messageListArea

                // ── Input / Selection Bar ──────────────────────────────
                if isSelectionMode {
                    selectionBottomBar
                } else {
                    inputBar
                }
            }

            // ── PiP Video ────────────────────────────────────────────
            if isPiPActive {
                PiPVideoView()
                    .offset(pipOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                pipOffset = CGSize(
                                    width: value.translation.width + pipOffset.width,
                                    height: value.translation.height + pipOffset.height
                                )
                            }
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            firebaseManager.listenToMessages(roomId: roomId)
            // Pastikan data users dan rooms sudah ter-load
            if firebaseManager.users.isEmpty {
                firebaseManager.listenToUsers()
            }
            if firebaseManager.chatRooms.isEmpty {
                firebaseManager.listenToChatRooms()
            }
        }
        .onDisappear {
            firebaseManager.removeMessagesListener()
            Task { @MainActor in
                firebaseManager.setTypingStatus(roomId: roomId, isTyping: false)
            }
        }
        .onChange(of: isInputFocused) { _, isFocused in
            Task { @MainActor in
                isTyping = isFocused
                firebaseManager.setTypingStatus(roomId: roomId, isTyping: isFocused)
            }
        }
        .onChange(of: messageText) { _, newValue in
            // Handle local typing state
            let hasText = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasText && !isTyping {
                isTyping = true
                Task { @MainActor in
                    firebaseManager.setTypingStatus(roomId: roomId, isTyping: true)
                }
            } else if !hasText && isTyping {
                isTyping = false
                Task { @MainActor in
                    firebaseManager.setTypingStatus(roomId: roomId, isTyping: false)
                }
            }
            
            // Reset timer on every keystroke
            typingTimer?.invalidate()
            if hasText {
                typingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                    isTyping = false
                    Task { @MainActor in
                        firebaseManager.setTypingStatus(roomId: roomId, isTyping: false)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCallView) {
            CallView(isVideo: isVideoCall, channelName: currentChannelName, targetUserName: directChatTargetUser?.name ?? "User")
        }
        .onChange(of: currentChatRoom?.callStatus) { _, newStatus in
            if let status = newStatus, status.status == "ringing" {
                let currentUserId = AuthManager.shared.currentUser?.uid ?? ""
                if status.callerId != currentUserId {
                    self.currentChannelName = status.channelName
                    self.isVideoCall = status.isVideo
                    self.showIncomingCallAlert = true
                }
            } else if newStatus == nil || newStatus?.status == "ended" {
                self.showIncomingCallAlert = false
                if self.showCallView {
                    self.showCallView = false
                }
            }
        }
        .alert(isPresented: $showIncomingCallAlert) {
            Alert(
                title: Text("Panggilan Masuk"),
                message: Text("\(currentChatRoom?.callStatus?.callerName ?? "Seseorang") memanggil..."),
                primaryButton: .default(Text("Terima"), action: {
                    firebaseManager.updateCallStatus(roomId: roomId, status: "accepted")
                    self.showCallView = true
                }),
                secondaryButton: .destructive(Text("Tolak"), action: {
                    firebaseManager.endCall(roomId: roomId)
                })
            )
        }
    }

    // MARK: - Selection Header
    private var selectionHeader: some View {
        HStack {
            Button(action: {
                withAnimation {
                    isSelectionMode = false
                    selectedMessageIds.removeAll()
                }
            }) {
                Text("Batal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
            }
            
            Spacer()
            
            Text("\(selectedMessageIds.count) Terpilih")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                
            Spacer()
            
            Button(action: {
                if selectedMessageIds.count == displayMessages.count {
                    selectedMessageIds.removeAll()
                } else {
                    selectedMessageIds = Set(displayMessages.map { $0.id })
                }
            }) {
                Text(selectedMessageIds.count == displayMessages.count ? "Sembunyikan" : "Pilih Semua")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 3, y: 2)
    }

    // MARK: - Selection Bottom Bar
    private var selectionBottomBar: some View {
        HStack {
            Spacer()
            Button(action: {
                guard !selectedMessageIds.isEmpty else { return }
                firebaseManager.deleteMessages(messageIds: Array(selectedMessageIds))
                withAnimation {
                    isSelectionMode = false
                    selectedMessageIds.removeAll()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                    Text("Hapus (\(selectedMessageIds.count)) untuk Semua")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(selectedMessageIds.isEmpty ? Color.gray : Color.red)
                .cornerRadius(24)
                .shadow(color: selectedMessageIds.isEmpty ? Color.clear : Color.red.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(selectedMessageIds.isEmpty)
            Spacer()
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: -4)
    }

    // MARK: - Header
    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }

            // Avatar
            ZStack {
                let initial = roomName.isEmpty ? "C" : String(roomName.prefix(1)).uppercased()
                if let targetUser = directChatTargetUser,
                   let avatarUrl = targetUser.avatarUrl,
                   !avatarUrl.isEmpty,
                   let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.2))
                            .overlay(Text(initial).font(.system(size: 16, weight: .bold)).foregroundColor(.white))
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 42, height: 42)
                    Text(initial)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                // Online indicator
                if let targetUser = directChatTargetUser {
                    Circle()
                        .fill(targetUser.isOnline ? Color.green : Color.gray)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 14, y: 14)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 14, y: 14)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(roomName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                HStack(spacing: 4) {
                    let isOnline = directChatTargetUser?.isOnline ?? true
                    Circle().fill(isOnline ? Color.green : Color.gray).frame(width: 6, height: 6)
                    Text(isOnline ? Localized.string(key: "online", lang: appLanguage) : Localized.string(key: "offline", lang: appLanguage))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    startCall(isVideo: true)
                }) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.black)
                        .padding(9)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }

                Button(action: {
                    startCall(isVideo: false)
                }) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.black)
                        .padding(9)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
        )
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Reply Banner
            if let replyId = replyingToMessageId, let repliedMsg = displayMessages.first(where: { $0.id == replyId }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localized.string(key: "replying_to", lang: appLanguage))
                            .font(.caption)
                            .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                            .bold()
                        Text(repliedMsg.text)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(action: { withAnimation { replyingToMessageId = nil } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.95, green: 0.95, blue: 0.98))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.black.opacity(0.05)), alignment: .top)
            }
            
            // Attachment tray
            if showAttachments {
                HStack(spacing: 20) {
                    AttachmentButton(icon: "doc.fill",      color: .blue,   title: "File")
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(Color.purple.opacity(0.15)).frame(width: 50, height: 50)
                                Image(systemName: "photo.fill").font(.system(size: 20)).foregroundColor(.purple)
                            }
                            Text("Foto").font(.caption).foregroundColor(.gray)
                        }
                    }
                    
                    AttachmentButton(icon: "camera.fill",   color: .orange, title: "Kamera", action: { 
                        showAttachments = false
                        showCamera = true
                    })
                    AttachmentButton(icon: "location.fill", color: .green,  title: "Lokasi", action: {
                        showAttachments = false
                        showLocationPicker = true
                    })
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main input row
            HStack(spacing: 10) {
                // + Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        showAttachments.toggle()
                        // ✅ Keyboard hilang saat attachment tray dibuka
                        if !showAttachments { isInputFocused = false }
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(showAttachments ? .white : Color(red: 0.45, green: 0.35, blue: 0.9))
                        .rotationEffect(.degrees(showAttachments ? 45 : 0))
                        .padding(10)
                        .background(showAttachments
                            ? Color(red: 0.45, green: 0.35, blue: 0.9)
                            : Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.12))
                        .clipShape(Circle())
                }

                // Text field or Recording UI
                if isRecording {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(recordingDuration.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0) // Blinking dot
                            .animation(.linear(duration: 0.5).repeatForever(), value: recordingDuration)
                        
                        Text(formatDuration(recordingDuration))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Text("< Slide to cancel")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .opacity(0.8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.93, green: 0.93, blue: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    HStack {
                        TextField(Localized.string(key: "type_message", lang: appLanguage), text: $messageText, axis: .vertical)
                            .lineLimit(1...4)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .focused($isInputFocused)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                        if !messageText.isEmpty {
                            Button(action: { messageText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.trailing, 10)
                            }
                        }
                    }
                    .background(Color(red: 0.93, green: 0.93, blue: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }

                // Send / Mic button
                if !messageText.isEmpty {
                    Button(action: sendMessage) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.45, green: 0.35, blue: 0.9))
                                .frame(width: 42, height: 42)
                                .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.4), radius: 8, y: 4)

                            Image(systemName: "arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .scaleEffect(1.1)
                        }
                    }
                } else {
                    // Voice Note Mic Button
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.gray.opacity(0.25))
                            .frame(width: isRecording ? 60 : 42, height: isRecording ? 60 : 42)
                            .shadow(color: isRecording ? Color.red.opacity(0.4) : .clear, radius: 8, y: 4)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isRecording ? .white : .gray)
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                    }
                    .offset(x: micDragOffset)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
                    .animation(.interactiveSpring(), value: micDragOffset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isRecording && !hasCancelledDrag {
                                    startRecording()
                                }
                                
                                if isRecording {
                                    if value.translation.width < 0 {
                                        micDragOffset = max(-150, value.translation.width)
                                        if micDragOffset <= -100 {
                                            hasCancelledDrag = true
                                            cancelRecording()
                                        }
                                    }
                                }
                            }
                            .onEnded { value in
                                if isRecording {
                                    if value.translation.width > -100 {
                                        stopRecording()
                                    } else {
                                        cancelRecording()
                                    }
                                }
                                hasCancelledDrag = false
                            }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: -4)
        }
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    do {
                        let imageUrl = try await firebaseManager.uploadImage(image: uiImage)
                        await MainActor.run {
                            withAnimation(.spring(response: 0.3)) {
                                firebaseManager.sendMessage(roomId: roomId, text: "Foto", replyToId: replyingToMessageId, imageUrl: imageUrl)
                                showAttachments = false
                                replyingToMessageId = nil
                                selectedPhotoItem = nil
                            }
                        }
                    } catch {
                        print("Failed to upload image: \(error.localizedDescription)")
                    }
                }
            }
        }
        .onChange(of: capturedImage) { oldValue, newValue in
            if let uiImage = newValue {
                Task {
                    do {
                        let imageUrl = try await firebaseManager.uploadImage(image: uiImage)
                        await MainActor.run {
                            withAnimation(.spring(response: 0.3)) {
                                firebaseManager.sendMessage(roomId: roomId, text: "Foto dari Kamera", replyToId: replyingToMessageId, imageUrl: imageUrl)
                                showAttachments = false
                                replyingToMessageId = nil
                                capturedImage = nil
                            }
                        }
                    } catch {
                        print("Failed to upload camera image: \(error.localizedDescription)")
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $capturedImage)
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView { lat, lng in
                firebaseManager.sendMessage(roomId: roomId, text: "Lokasi", locationLat: lat, locationLng: lng)
            }
        }
    }

    // MARK: - Actions
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        withAnimation(.spring(response: 0.3)) {
            firebaseManager.sendMessage(roomId: roomId, text: trimmed, replyToId: replyingToMessageId)
            messageText = ""
            replyingToMessageId = nil
        }
        isInputFocused = false
    }

    private func startRecording() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        audioRecorder.startRecording()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isRecording = true
            recordingDuration = 0
            micDragOffset = 0
        }
        
        voiceNoteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func cancelRecording() {
        if !isRecording { return }
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
        
        audioRecorder.cancelRecording()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isRecording = false
            micDragOffset = 0
        }
        voiceNoteTimer?.invalidate()
        voiceNoteTimer = nil
        recordingDuration = 0
    }
    
    private func stopRecording() {
        if !isRecording { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        
        audioRecorder.stopRecording()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isRecording = false
            micDragOffset = 0
        }
        voiceNoteTimer?.invalidate()
        voiceNoteTimer = nil
        
        if recordingDuration > 1.0, let url = audioRecorder.recordingURL {
            Task {
                do {
                    let uploadedUrl = try await firebaseManager.uploadAudio(fileURL: url)
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3)) {
                            firebaseManager.sendMessage(roomId: roomId, text: "Voice Note", replyToId: replyingToMessageId, audioUrl: uploadedUrl)
                            replyingToMessageId = nil
                        }
                    }
                } catch {
                    print("Failed to upload audio: \(error.localizedDescription)")
                }
            }
        }
        recordingDuration = 0
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Legacy Mocks Removed
    
    // sendMockImage removed
    
    private func startCall(isVideo: Bool) {
        let currentUserId = AuthManager.shared.currentUser?.uid ?? ""
        let callerName = firebaseManager.users.first(where: { $0.id == currentUserId })?.name ?? "User"
        // Menggunakan nama channel statis untuk keperluan testing dengan Temp Token
        let channelName = "testroom"
        firebaseManager.initiateCall(roomId: roomId, callerId: currentUserId, callerName: callerName, isVideo: isVideo, channelName: channelName)
        
        self.currentChannelName = channelName
        self.isVideoCall = isVideo
        self.showCallView = true
    }

    private func simulateTyping() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { isTyping = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { isTyping = false }
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    let roomType: String
    let showReaction: Bool
    let repliedMessage: Message?
    let isSelectionMode: Bool
    let isSelected: Bool
    let onLongPress: () -> Void
    let onReact: (String) -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    private let reactions = ["❤️", "👍", "😂", "😮", "😢", "🙏"]

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
            if showReaction {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(reactions, id: \.self) { emoji in
                            Button(action: { onReact(emoji) }) {
                                Text(emoji)
                                    .font(.title2)
                                    .padding(6)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            }
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                    HStack(spacing: 16) {
                        Button(action: onReply) {
                            HStack {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                Text("Reply")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        if message.isUser {
                            Button(action: onDelete) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Delete")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .clipShape(Capsule())
                            }
                        }
                        Button(action: onSelect) {
                            HStack {
                                Image(systemName: "checklist")
                                Text("Pilih")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                    }
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .transition(.scale(scale: 0.5, anchor: message.isUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 8) {
                if isSelectionMode {
                    Button(action: onSelect) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? Color(red: 0.45, green: 0.35, blue: 0.9) : .gray)
                            .padding(.trailing, 4)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                if message.isUser { Spacer(minLength: 60) }

                let showAvatar = !message.isUser && (roomType == "group" || roomType == "bot")
                let showSenderName = !message.isUser && (roomType == "group")

                if showAvatar {
                    // Avatar with image or first letter of senderName
                    let matchedUser = FirebaseManager.shared.users.first(where: { $0.id == message.senderId })
                    if let avatarUrl = matchedUser?.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    } else {
                        let initial = message.senderName.isEmpty ? "C" : String(message.senderName.prefix(1)).uppercased()
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.6), Color.blue.opacity(0.4)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                            .overlay(Text(initial).font(.system(size: 11, weight: .bold)).foregroundColor(.white))
                    }
                }

                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                    if showSenderName {
                        // Display real username
                        Text(message.senderName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                    }
                    
                    // Bubble
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                        if let replied = repliedMessage {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(replied.isUser ? "You" : "Them")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(message.isUser ? .white.opacity(0.9) : Color(red: 0.45, green: 0.35, blue: 0.9))
                                Text(replied.text)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .foregroundColor(message.isUser ? .white.opacity(0.8) : .gray)
                            }
                            .padding(8)
                            .background(message.isUser ? Color.white.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.bottom, 4)
                        }
                        
                        if let lat = message.locationLat, let lng = message.locationLng {
                            // Map Preview
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(message.isUser ? .white : Color(red: 0.45, green: 0.35, blue: 0.9))
                                    .padding(.bottom, 4)
                                Text("📍 Lokasi Dibagikan")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Text("\(lat), \(lng)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .opacity(0.7)
                            }
                        } else if let imageUrl = message.imageUrl {
                            if imageUrl.hasPrefix("data:image"),
                               let base64String = imageUrl.components(separatedBy: ",").last,
                               let data = Data(base64Encoded: base64String),
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: 240, maxHeight: 300)
                                    .cornerRadius(12)
                            } else if let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
                                                .frame(width: 200, height: 150)
                                            ProgressView()
                                        }
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: 240, maxHeight: 300)
                                            .cornerRadius(12)
                                    case .failure:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
                                                .frame(width: 200, height: 150)
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white)
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
                                        .frame(width: 200, height: 150)
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                            }
                        } else if message.audioUrl != nil {
                            HStack(spacing: 8) {
                                Button(action: {}) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 28))
                                }
                                
                                // Mock Waveform
                                HStack(spacing: 3) {
                                    ForEach(0..<10, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(message.isUser ? Color.white.opacity(0.8) : Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.6))
                                            .frame(width: 3, height: CGFloat.random(in: 8...24))
                                    }
                                }
                                .padding(.horizontal, 4)
                                
                                Text("0:05")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                            }
                            .foregroundColor(message.isUser ? .white : Color(red: 0.45, green: 0.35, blue: 0.9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                        } else {
                            Text(message.text)
                                .font(.system(size: 15))
                        }
                    }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.isUser
                                ? LinearGradient(colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.55, green: 0.4, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.white, Color.white], startPoint: .top, endPoint: .bottom)
                        )
                        .foregroundColor(message.isUser ? .white : .black)
                        .clipShape(
                            RoundedCorner(
                                radius: 18,
                                corners: message.isUser
                                    ? [.topLeft, .topRight, .bottomLeft]
                                    : [.topLeft, .topRight, .bottomRight]
                            )
                        )
                        .shadow(color: Color.black.opacity(0.07), radius: 6, y: 3)

                    // Timestamp + Status
                    HStack(spacing: 4) {
                        Text(message.timestamp.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        if message.isUser {
                            StatusIcon(status: message.status)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelectionMode {
                        onSelect()
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    if !isSelectionMode {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onLongPress()
                    }
                }

                if !message.isUser { Spacer(minLength: 60) }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var phase: Int = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.6), Color.blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
                .overlay(Text("M").font(.system(size: 11, weight: .bold)).foregroundColor(.white))

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.4 : 1.0)
                        .animation(.spring(response: 0.3), value: phase)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedCorner(radius: 18, corners: [.topLeft, .topRight, .bottomRight]))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)

            Spacer(minLength: 60)
        }
        .padding(.vertical, 2)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

// MARK: - Date Separator
struct DateSeparator: View {
    let label: String
    var body: some View {
        HStack {
            VStack { Divider() }
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 0.9, green: 0.89, blue: 0.95))
                .clipShape(Capsule())
            VStack { Divider() }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Status Icon
struct StatusIcon: View {
    let status: Message.MessageStatus
    var body: some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "clock").foregroundColor(.gray.opacity(0.6))
            case .sent:
                Image(systemName: "checkmark").foregroundColor(.gray)
            case .delivered:
                Image(systemName: "checkmark.circle").foregroundColor(.gray)
            case .read:
                Image(systemName: "checkmark.circle.fill").foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
            }
        }
        .font(.system(size: 9, weight: .semibold))
    }
}

// MARK: - Attachment Button
struct AttachmentButton: View {
    let icon: String
    let color: Color
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: icon).foregroundColor(color).font(.system(size: 20)))
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - PiP Video
struct PiPVideoView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.black).frame(width: 130, height: 170)

            LinearGradient(colors: [.purple.opacity(0.6), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(width: 130, height: 170)

            // Animated pulse
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.4 : 1.0)
                .opacity(isAnimating ? 0 : 0.8)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }

            Image(systemName: "person.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.8))

            VStack {
                Spacer()
                HStack {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("Dr. Elena")
                        .font(.caption2).bold().foregroundColor(.white)
                }
                .padding(6)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(8)
            }
        }
        .frame(width: 130, height: 170)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }
}

// MARK: - Rounded Corner Helper
struct RoundedCorner: Shape {
    var radius: CGFloat = 16
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
