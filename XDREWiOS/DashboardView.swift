import SwiftUI
struct ChatModel: Identifiable {
    let id = UUID()
    let roomId: String
    let name: String
    let message: String
    let time: String
    let unread: Int
    let isOnline: Bool
    let isSpace: Bool
    let type: String
    let color: Color
    var avatarUrl: String?
}
enum ChatFilter: String, CaseIterable {
    case all = "Semua"
    case direct = "Teman"
    case group = "Grup"
    case bot = "Bot"
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedTab = 0
    
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showEditProfileSheet = false
    @State private var selectedFilter: ChatFilter = .all
    @State private var showNewChatSheet = false
    @State private var showSettings = false
    @State private var navigateToRoomId: String? = nil
    @AppStorage("app_language") var appLanguage: AppLanguage = .english
    @State private var showLanguageSheet = false
    @State private var showDeleteAllAlert = false
    
    // Mock chats dihapus — hanya tampilkan data dari Firebase
    let mockChats: [ChatModel] = []
    
    var currentUserProfile: FirebaseUser? {
        guard let uid = AuthManager.shared.currentUser?.uid else { return nil }
        return firebaseManager.users.first(where: { $0.id == uid })
    }
    
    var activeChats: [ChatModel] {
        // Hanya tampilkan data dari Firebase — tidak ada mock data
        guard !firebaseManager.chatRooms.isEmpty else { return [] }
        
        let rooms = firebaseManager.chatRooms.filter { room in
            let type = room.type ?? (room.isSpace ? "space" : (room.id?.contains("bot") == true ? "bot" : "group"))
            switch selectedFilter {
            case .all:
                return !room.isSpace
            case .direct:
                return type == "direct"
            case .group:
                return type == "group"
            case .bot:
                return type == "bot"
            }
        }
        
        return rooms.map { room in
            let timeString: String
            if room.isSpace {
                timeString = "Live"
            } else {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                timeString = formatter.localizedString(for: room.updatedAt, relativeTo: Date())
            }
            
            var displayName = room.name
            var displayAvatar: String? = nil
            if room.type == "direct", let members = room.memberIds {
                let currentUserId = AuthManager.shared.currentUser?.uid ?? ""
                if let otherUserId = members.first(where: { $0 != currentUserId }),
                   let matchedUser = firebaseManager.users.first(where: { $0.id == otherUserId }) {
                    displayName = matchedUser.name
                    displayAvatar = matchedUser.avatarUrl
                }
            }
            
            let computedType = room.type ?? (room.isSpace ? "space" : (room.id?.contains("bot") == true ? "bot" : "group"))
            return ChatModel(
                roomId: room.id ?? "unknown",
                name: displayName,
                message: room.lastMessage,
                time: timeString,
                unread: 0,
                isOnline: true,
                isSpace: room.isSpace,
                type: computedType,
                color: room.isSpace ? .purple : (computedType == "bot" ? .green : (computedType == "direct" ? .orange : .blue)),
                avatarUrl: displayAvatar
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.94, blue: 0.98).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header & Search
                    VStack(spacing: 16) {
                        HStack {
                            Text("XDREW Chat")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            // Removed settings button as requested
                            // Tambah Chat Baru Button
                            if selectedTab == 0 {
                                Button(action: { showNewChatSheet = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                                }
                                .padding(.leading, 10)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.gray)
                                .font(.system(size: 16, weight: .medium))
                            TextField(Localized.string(key: "search_placeholder", lang: appLanguage), text: $searchText)
                                .foregroundColor(.black)
                                .font(.system(size: 16, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        
                        // Kategori Filter Obrolan (Hanya di tab Chats)
                        if selectedTab == 0 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(ChatFilter.allCases, id: \.self) { filter in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedFilter = filter
                                            }
                                        }) {
                                            let localizedName: String = {
                                                switch filter {
                                                case .all: return Localized.string(key: "filter_all", lang: appLanguage)
                                                case .direct: return Localized.string(key: "filter_friends", lang: appLanguage)
                                                case .group: return Localized.string(key: "filter_groups", lang: appLanguage)
                                                case .bot: return Localized.string(key: "filter_bot", lang: appLanguage)
                                                }
                                            }()
                                            Text(localizedName)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(selectedFilter == filter ? Color(red: 0.45, green: 0.35, blue: 0.9) : Color(.systemGray6))
                                                .foregroundColor(selectedFilter == filter ? .white : .gray)
                                                .clipShape(Capsule())
                                                .shadow(color: selectedFilter == filter ? Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.3) : Color.clear, radius: 4, y: 2)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .padding(.horizontal, -16) // offset default padding
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
                    
                    if selectedTab == 3 {
                        // Settings Tab
                        ScrollView {
                            VStack(spacing: 24) {
                                // Profile Header Card
                                VStack(spacing: 16) {
                                    Button(action: { showEditProfileSheet = true }) {
                                        ZStack(alignment: .bottomTrailing) {
                                            if let avatarUrl = currentUserProfile?.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                                                AsyncImage(url: url) { image in
                                                    image.resizable().scaledToFill()
                                                } placeholder: {
                                                    Circle().fill(Color.gray.opacity(0.2))
                                                }
                                                .frame(width: 90, height: 90)
                                                .clipShape(Circle())
                                                .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.2), radius: 10, y: 5)
                                            } else {
                                                Circle()
                                                    .fill(LinearGradient(
                                                        colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                                    ))
                                                    .frame(width: 90, height: 90)
                                                    .overlay(
                                                        Text(AuthManager.shared.userInitial)
                                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                                            .foregroundColor(.white)
                                                    )
                                                    .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.3), radius: 10, y: 5)
                                            }
                                            
                                            // Edit Icon
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Image(systemName: "pencil")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                                                )
                                                .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                                        }
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text(currentUserProfile?.name ?? AuthManager.shared.displayName)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                        
                                        Text(AuthManager.shared.currentUser?.email ?? AuthManager.shared.currentUser?.phoneNumber ?? Localized.string(key: "active_account", lang: appLanguage))
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Button(action: { showEditProfileSheet = true }) {
                                        Text(Localized.string(key: "edit_profile", lang: appLanguage))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 8)
                                            .background(Color.black)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(24)
                                .shadow(color: Color.black.opacity(0.03), radius: 15, y: 10)
                                .padding(.horizontal)
                                
                                // Preferences Section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(Localized.string(key: "preferences", lang: appLanguage))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                        .padding(.leading, 8)
                                    
                                    VStack(spacing: 0) {
                                        SettingsRow(icon: "bell.fill", color: .orange, title: Localized.string(key: "notifications", lang: appLanguage), showToggle: true, toggleState: true)
                                        Divider().padding(.leading, 56)
                                        SettingsRow(icon: "moon.fill", color: .indigo, title: Localized.string(key: "dark_mode", lang: appLanguage), showToggle: true, toggleState: false)
                                        Divider().padding(.leading, 56)
                                        Button(action: { showLanguageSheet = true }) {
                                            SettingsRow(icon: "globe", color: .blue, title: Localized.string(key: "language", lang: appLanguage), value: appLanguage.displayName)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                                }
                                .padding(.horizontal)
                                
                                // Account & Support Section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(Localized.string(key: "account_support", lang: appLanguage))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                        .padding(.leading, 8)
                                    
                                    VStack(spacing: 0) {
                                        SettingsRow(icon: "lock.fill", color: .green, title: Localized.string(key: "privacy_security", lang: appLanguage))
                                        Divider().padding(.leading, 56)
                                        SettingsRow(icon: "questionmark.circle.fill", color: .mint, title: Localized.string(key: "help_support", lang: appLanguage))
                                        Divider().padding(.leading, 56)
                                        SettingsRow(icon: "info.circle.fill", color: .gray, title: Localized.string(key: "about", lang: appLanguage), value: "v1.0.0")
                                    }
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                                }
                                .padding(.horizontal)
                                
                                // Logout Button
                                Button(action: {
                                    try? AuthManager.shared.signOut()
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text(Localized.string(key: "logout", lang: appLanguage))
                                    }
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.red.opacity(0.1), radius: 10, y: 5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                
                                // Tombol Hapus Semua Data Lama
                                Button(action: { showDeleteAllAlert = true }) {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text(appLanguage == .indonesian ? "Hapus Semua Data Lama" : "Delete All Old Data")
                                    }
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.orange.opacity(0.1), radius: 10, y: 5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal)
                                .padding(.top, 4)
                                .padding(.bottom, 30)
                                .alert(
                                    appLanguage == .indonesian ? "Hapus Semua Data?" : "Delete All Data?",
                                    isPresented: $showDeleteAllAlert
                                ) {
                                    Button(appLanguage == .indonesian ? "Hapus" : "Delete", role: .destructive) {
                                        firebaseManager.deleteAllMockData { }
                                    }
                                    Button(appLanguage == .indonesian ? "Batal" : "Cancel", role: .cancel) { }
                                } message: {
                                    Text(appLanguage == .indonesian
                                         ? "Ini akan menghapus semua rooms dan pesan dari Firestore. Tindakan ini tidak bisa dibatalkan."
                                         : "This will delete all rooms and messages from Firestore. This action cannot be undone.")
                                }
                            }
                            .padding(.top, 16)
                        }
                        .transition(.opacity)
                    } else if selectedTab == 1 {
                        // Calls Tab
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(firebaseManager.calls) { call in
                                    CallRow(call: call)
                                }
                                if firebaseManager.calls.isEmpty {
                                    VStack {
                                        Spacer().frame(height: 100)
                                        Image(systemName: "phone.badge.plus")
                                            .font(.system(size: 60))
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.bottom, 8)
                                        Text("Belum ada panggilan")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                        }
                    } else if selectedTab == 2 {
                        // Spaces Tab
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(activeChats.filter { $0.isSpace }) { chat in
                                    NavigationLink(destination: AnyView(VoiceSpaceView())) {
                                        ChatRow(chat: chat)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                if activeChats.filter({ $0.isSpace }).isEmpty {
                                    VStack {
                                        Spacer().frame(height: 100)
                                        Image(systemName: "waveform.circle")
                                            .font(.system(size: 60))
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.bottom, 8)
                                        Text("Belum ada space aktif")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                        }
                    } else {
                        // Chat List (selectedTab == 0)
                            let chatList = activeChats.filter { !$0.isSpace }
                            let directChats = chatList.filter { $0.type == "direct" || $0.type == "bot" }
                            let groupChats = chatList.filter { $0.type == "group" }
                            
                            if chatList.isEmpty {
                                // Empty state
                                VStack(spacing: 16) {
                                    Spacer()
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 64))
                                        .foregroundColor(.gray.opacity(0.35))
                                    Text(appLanguage == .indonesian ? "Belum ada obrolan" : "No conversations yet")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    Text(appLanguage == .indonesian ? "Ketuk + untuk memulai obrolan baru" : "Tap + to start a new conversation")
                                        .font(.subheadline)
                                        .foregroundColor(.gray.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                    Spacer()
                                }
                                .padding()
                            } else {
                                List {
                                    if !directChats.isEmpty {
                                        Section(header: Text(appLanguage == .indonesian ? "Pribadi" : "Direct Messages").font(.headline).foregroundColor(.gray)) {
                                            ForEach(directChats) { chat in
                                                ZStack {
                                                    ChatRow(chat: chat)
                                                    NavigationLink(destination: ChatEngineView(roomId: chat.roomId)) {
                                                        EmptyView()
                                                    }
                                                    .opacity(0)
                                                }
                                                .listRowBackground(Color.clear)
                                                .listRowSeparator(.hidden)
                                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                    Button(role: .destructive) {
                                                        firebaseManager.deleteChatRoom(roomId: chat.roomId)
                                                    } label: {
                                                        Label(
                                                            appLanguage == .indonesian ? "Hapus" : "Delete",
                                                            systemImage: "trash.fill"
                                                        )
                                                    }
                                                }

                                            }
                                        }
                                    }
                                    
                                    if !groupChats.isEmpty {
                                        Section(header: Text(appLanguage == .indonesian ? "Grup / Chat Room" : "Groups & Rooms").font(.headline).foregroundColor(.gray)) {
                                            ForEach(groupChats) { chat in
                                                ZStack {
                                                    ChatRow(chat: chat)
                                                    NavigationLink(destination: ChatEngineView(roomId: chat.roomId)) {
                                                        EmptyView()
                                                    }
                                                    .opacity(0)
                                                }
                                                .listRowBackground(Color.clear)
                                                .listRowSeparator(.hidden)
                                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                    Button(role: .destructive) {
                                                        firebaseManager.deleteChatRoom(roomId: chat.roomId)
                                                    } label: {
                                                        Label(
                                                            appLanguage == .indonesian ? "Hapus" : "Delete",
                                                            systemImage: "trash.fill"
                                                        )
                                                    }
                                                }

                                            }
                                        }
                                    }
                                }
                                .listStyle(.plain)
                            .background(Color.clear)
                        }
                    }
                    
                    // Custom Tab Bar
                    HStack(spacing: 0) {
                        TabBarItem(icon: "message.fill", title: appLanguage == .indonesian ? "Obrolan" : "Chats", isSelected: selectedTab == 0) { selectedTab = 0 }
                        TabBarItem(icon: "phone.fill", title: appLanguage == .indonesian ? "Panggilan" : "Calls", isSelected: selectedTab == 1) { selectedTab = 1 }
                        TabBarItem(icon: "waveform.circle.fill", title: "Spaces", isSelected: selectedTab == 2) { selectedTab = 2 }
                        TabBarItem(icon: "gearshape.fill", title: appLanguage == .indonesian ? "Pengaturan" : "Settings", isSelected: selectedTab == 3) { selectedTab = 3 }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, y: -5)
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { navigateToRoomId != nil },
                    set: { if !$0 { navigateToRoomId = nil } }
                )
            ) {
                ChatEngineView(roomId: navigateToRoomId ?? "")
            }
        }
        .onAppear {
            firebaseManager.listenToChatRooms()
            firebaseManager.listenToCalls()
            firebaseManager.listenToUsers()
        }
        .sheet(isPresented: $showEditProfileSheet) {
            EditProfileSheet(currentUserProfile: currentUserProfile)
        }
        .sheet(isPresented: $showNewChatSheet) {
            NewChatSheet { roomId in
                self.navigateToRoomId = roomId
            }
        }
        .sheet(isPresented: $showLanguageSheet) {
            LanguageSelectionSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

struct CallRow: View {
    let call: FirebaseCall
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.9, green: 0.9, blue: 0.95))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(call.callerName)
                    .font(.headline)
                    .foregroundColor(call.status == "missed" ? .red : .black)
                
                HStack(spacing: 4) {
                    Image(systemName: call.type == "video" ? "video.fill" : "phone.fill")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(call.status.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                let formatter = RelativeDateTimeFormatter()
                Text(formatter.localizedString(for: call.timestamp, relativeTo: Date()))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: {}) {
                    Image(systemName: call.type == "video" ? "video" : "phone")
                        .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                        .padding(8)
                        .background(Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2)
    }
}

struct ChatRow: View {
    let chat: ChatModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                if let avatarUrl = chat.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                } else {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [chat.color, chat.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 56, height: 56)
                            .shadow(color: chat.color.opacity(0.3), radius: 4, y: 2)
                        
                        Text(String(chat.name.prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                if chat.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .offset(x: -2, y: -2)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(chat.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text(chat.message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Meta
            VStack(alignment: .trailing, spacing: 8) {
                Text(chat.time)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(chat.isSpace ? .red : Color.gray.opacity(0.8))
                
                if chat.unread > 0 {
                    Circle()
                        .fill(LinearGradient(colors: [Color(red: 0.5, green: 0.4, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 22, height: 22)
                        .overlay(Text("\(chat.unread)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white))
                        .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.3), radius: 4, y: 2)
                } else {
                    Spacer().frame(height: 22) // maintain alignment
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color(red: 0.45, green: 0.35, blue: 0.9) : .gray)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Color(red: 0.45, green: 0.35, blue: 0.9) : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    var value: String? = nil
    var showToggle: Bool = false
    @State var toggleState: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            } else if showToggle {
                Toggle("", isOn: $toggleState)
                    .labelsHidden()
                    .tint(Color(red: 0.45, green: 0.35, blue: 0.9))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.white)
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let currentUserProfile: FirebaseUser?
    
    @State private var name: String = ""
    @State private var avatarUrl: String = ""
    @State private var selectedPresetIndex: Int? = nil
    @AppStorage("app_language") var appLanguage: AppLanguage = .english
    let presets = [
        "https://robohash.org/kitty1.png?set=set4",
        "https://robohash.org/kitty2.png?set=set4",
        "https://robohash.org/monster1.png?set=set2",
        "https://robohash.org/monster2.png?set=set2",
        "https://robohash.org/robot1.png?set=set1"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Profile Preview
                    VStack(spacing: 12) {
                        if !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.3), radius: 10, y: 5)
                        } else {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(String(name.prefix(1)).uppercased())
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.3), radius: 10, y: 5)
                        }
                        Text("Pratinjau Avatar")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top)
                    
                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Localized.string(key: "username_label", lang: appLanguage))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                        
                        TextField("Masukkan nama...", text: $name)
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                    }
                    .padding(.horizontal)
                    
                    // Avatar preset selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Localized.string(key: "choose_avatar", lang: appLanguage))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<presets.count, id: \.self) { index in
                                    Button(action: {
                                        selectedPresetIndex = index
                                        avatarUrl = presets[index]
                                    }) {
                                        AsyncImage(url: URL(string: presets[index])) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Circle().fill(Color.gray.opacity(0.2))
                                        }
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color(red: 0.45, green: 0.35, blue: 0.9), lineWidth: selectedPresetIndex == index ? 4 : 0)
                                        )
                                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Custom URL input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Localized.string(key: "custom_avatar", lang: appLanguage))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                        
                        TextField("https://link-foto-anda.com/foto.jpg", text: $avatarUrl)
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .background(Color(red: 0.95, green: 0.94, blue: 0.98).ignoresSafeArea())
            .navigationTitle(Localized.string(key: "edit_profile", lang: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Localized.string(key: "cancel_btn", lang: appLanguage)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Localized.string(key: "save", lang: appLanguage)) {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty {
                            FirebaseManager.shared.updateUserProfile(name: trimmedName, avatarUrl: avatarUrl)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                    .bold()
                }
            }
        }
        .onAppear {
            if let profile = currentUserProfile {
                name = profile.name
                avatarUrl = profile.avatarUrl ?? ""
                if let idx = presets.firstIndex(of: avatarUrl) {
                    selectedPresetIndex = idx
                }
            } else {
                name = AuthManager.shared.displayName
            }
        }
    }
}

// MARK: - New Chat Sheet
struct NewChatSheet: View {
    @Environment(\.presentationMode) var presentationMode
    var onRoomCreated: (String) -> Void
    
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var selectedSheetTab = 0 // 0: DM, 1: Bot, 2: Group
    @AppStorage("app_language") var appLanguage: AppLanguage = .english
    
    // Group fields
    @State private var groupName = ""
    @State private var selectedUserIds = Set<String>()
    
    var otherUsers: [FirebaseUser] {
        let currentUid = AuthManager.shared.currentUser?.uid ?? ""
        return firebaseManager.users.filter { $0.id != currentUid }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab/Pill Selector
                Picker("Tab", selection: $selectedSheetTab) {
                    Text(Localized.string(key: "tab_friends", lang: appLanguage)).tag(0)
                    Text(Localized.string(key: "tab_bot", lang: appLanguage)).tag(1)
                    Text(Localized.string(key: "tab_group", lang: appLanguage)).tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ZStack {
                    Color(red: 0.95, green: 0.94, blue: 0.98).ignoresSafeArea()
                    
                    if selectedSheetTab == 0 {
                        // Direct Chat Tab
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(otherUsers) { user in
                                    Button(action: {
                                        let currentUid = AuthManager.shared.currentUser?.uid ?? ""
                                        let targetUid = user.id ?? ""
                                        firebaseManager.createChatRoom(
                                            name: user.name,
                                            isSpace: false,
                                            type: "direct",
                                            memberIds: [currentUid, targetUid]
                                        ) { roomId in
                                            if !roomId.isEmpty {
                                                onRoomCreated(roomId)
                                                presentationMode.wrappedValue.dismiss()
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 16) {
                                            if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                                                AsyncImage(url: url) { image in
                                                    image.resizable().scaledToFill()
                                                } placeholder: {
                                                    Circle().fill(Color.gray.opacity(0.2))
                                                }
                                                .frame(width: 46, height: 46)
                                                .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(LinearGradient(
                                                        colors: [Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.6), Color.blue.opacity(0.4)],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    .frame(width: 46, height: 46)
                                                    .overlay(
                                                        Text(String(user.name.prefix(1)).uppercased())
                                                            .font(.headline)
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(user.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.black)
                                                Text(user.email)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray.opacity(0.5))
                                        }
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(16)
                                        .shadow(color: .black.opacity(0.02), radius: 6, y: 3)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                if otherUsers.isEmpty {
                                    VStack(spacing: 12) {
                                        Spacer().frame(height: 60)
                                        Image(systemName: "person.2.slash.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray.opacity(0.4))
                                        Text(Localized.string(key: "no_users", lang: appLanguage))
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                        }
                    } else if selectedSheetTab == 1 {
                        // Bot Chat Tab
                        VStack(spacing: 24) {
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.green.opacity(0.2), Color.teal.opacity(0.3)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 140, height: 140)
                                
                                Image(systemName: "cpu")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Nexus Assistant Bot")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                
                                Text("Asisten AI pintar yang siap menjawab pertanyaan Anda kapan saja.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            
                            Button(action: {
                                let currentUid = AuthManager.shared.currentUser?.uid ?? ""
                                firebaseManager.createChatRoom(
                                    name: "Nexus Bot",
                                    isSpace: false,
                                    type: "bot",
                                    memberIds: [currentUid]
                                ) { roomId in
                                    if !roomId.isEmpty {
                                        onRoomCreated(roomId)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                    Text(Localized.string(key: "tab_bot", lang: appLanguage))
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(16)
                                .shadow(color: Color.green.opacity(0.3), radius: 10, y: 5)
                            }
                            .padding(.horizontal, 32)
                            
                            Spacer()
                        }
                        .padding()
                    } else {
                        // Group Chat Tab
                        VStack(spacing: 16) {
                            // Group Name Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text(Localized.string(key: "group_name", lang: appLanguage))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                                
                                TextField(Localized.string(key: "group_name_placeholder", lang: appLanguage), text: $groupName)
                                    .foregroundColor(.black)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(14)
                                    .shadow(color: .black.opacity(0.02), radius: 6, y: 3)
                            }
                            .padding([.horizontal, .top])
                            
                            // Member Selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text(Localized.string(key: "choose_members", lang: appLanguage))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                                
                                ScrollView {
                                    VStack(spacing: 10) {
                                        ForEach(otherUsers) { user in
                                            Button(action: {
                                                let uid = user.id ?? ""
                                                if selectedUserIds.contains(uid) {
                                                    selectedUserIds.remove(uid)
                                                } else {
                                                    selectedUserIds.insert(uid)
                                                }
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: selectedUserIds.contains(user.id ?? "") ? "checkmark.square.fill" : "square")
                                                        .font(.title3)
                                                        .foregroundColor(selectedUserIds.contains(user.id ?? "") ? Color(red: 0.45, green: 0.35, blue: 0.9) : .gray)
                                                    
                                                    if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                                                        AsyncImage(url: url) { image in
                                                            image.resizable().scaledToFill()
                                                        } placeholder: {
                                                            Circle().fill(Color.gray.opacity(0.2))
                                                        }
                                                        .frame(width: 36, height: 36)
                                                        .clipShape(Circle())
                                                    } else {
                                                        Circle()
                                                            .fill(Color.gray.opacity(0.2))
                                                            .frame(width: 36, height: 36)
                                                            .overlay(Text(String(user.name.prefix(1))).font(.caption).bold())
                                                    }
                                                    
                                                    Text(user.name)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundColor(.black)
                                                    Spacer()
                                                }
                                                .padding()
                                                .background(Color.white)
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                            
                            Button(action: {
                                let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmedName.isEmpty else { return }
                                
                                let currentUid = AuthManager.shared.currentUser?.uid ?? ""
                                var memberIds = Array(selectedUserIds)
                                memberIds.append(currentUid)
                                
                                firebaseManager.createChatRoom(
                                    name: trimmedName,
                                    isSpace: false,
                                    type: "group",
                                    memberIds: memberIds
                                ) { roomId in
                                    if !roomId.isEmpty {
                                        onRoomCreated(roomId)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            }) {
                                Text(Localized.string(key: "create_group", lang: appLanguage))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color(red: 0.45, green: 0.35, blue: 0.9))
                                    .cornerRadius(16)
                                    .shadow(color: groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .clear : Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.3), radius: 10, y: 5)
                            }
                            .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle(Localized.string(key: "start_new_chat", lang: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Localized.string(key: "cancel_btn", lang: appLanguage)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Language Selection Sheet
struct LanguageSelectionSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("app_language") var appLanguage: AppLanguage = .english
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AppLanguage.allCases) { lang in
                    Button(action: {
                        appLanguage = lang
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(lang.displayName)
                                .foregroundColor(.black)
                            Spacer()
                            if appLanguage == lang {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                                    .bold()
                            }
                        }
                    }
                }
            }
            .navigationTitle(Localized.string(key: "select_language", lang: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Localized.string(key: "done", lang: appLanguage)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .bold()
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                }
            }
        }
    }
}


