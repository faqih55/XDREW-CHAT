import SwiftUI
import AudioToolbox

struct SystemSound {
    let name: String
    let id: UInt32
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    
    // Some popular iOS System Sound IDs
    let systemSounds: [SystemSound] = [
        SystemSound(name: "Default / Note", id: 1007),
        SystemSound(name: "Ding", id: 1000),
        SystemSound(name: "Chime", id: 1008),
        SystemSound(name: "Glass", id: 1009),
        SystemSound(name: "Horn", id: 1010),
        SystemSound(name: "Bell", id: 1013),
        SystemSound(name: "Electronic", id: 1014),
        SystemSound(name: "Anticipate", id: 1020),
        SystemSound(name: "Bloom", id: 1021),
        SystemSound(name: "Calypso", id: 1022),
        SystemSound(name: "Choo Choo", id: 1023),
        SystemSound(name: "Descent", id: 1024)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Profil Anda")) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 60, height: 60)
                            
                            Text(String(authManager.currentUser?.displayName?.prefix(1) ?? "U").uppercased())
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.displayName ?? "User")
                                .font(.headline)
                            Text(authManager.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 10)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Pengaturan Aplikasi")) {
                    Toggle(isOn: $notificationManager.isNotificationsEnabled) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.orange)
                            }
                            Text("Notifikasi")
                                .font(.body)
                        }
                    }
                    .tint(Color.purple)
                    .onChange(of: notificationManager.isNotificationsEnabled) { oldValue, newValue in
                        notificationManager.toggleNotifications(enabled: newValue)
                    }
                    
                    if notificationManager.isNotificationsEnabled {
                        Toggle("Suara Di Dalam Chat", isOn: $notificationManager.inAppSoundEnabled)
                            .onChange(of: notificationManager.inAppSoundEnabled) { oldValue, newValue in
                                notificationManager.toggleInAppSound(enabled: newValue)
                            }
                            
                        if notificationManager.inAppSoundEnabled {
                            Picker("Nada Dalam Chat", selection: $notificationManager.inAppSoundID) {
                                ForEach(systemSounds, id: \.id) { sound in
                                    Text(sound.name).tag(sound.id)
                                }
                            }
                            .onChange(of: notificationManager.inAppSoundID) { oldValue, newValue in
                                notificationManager.updateInAppSoundPreference(to: newValue)
                            }
                        }
                        
                        Toggle("Suara Di Luar Chat", isOn: $notificationManager.backgroundSoundEnabled)
                            .onChange(of: notificationManager.backgroundSoundEnabled) { oldValue, newValue in
                                notificationManager.toggleBackgroundSound(enabled: newValue)
                            }
                            
                        if notificationManager.backgroundSoundEnabled {
                            Picker("Nada Luar Chat", selection: $notificationManager.backgroundSoundID) {
                                ForEach(systemSounds, id: \.id) { sound in
                                    Text(sound.name).tag(sound.id)
                                }
                            }
                            .onChange(of: notificationManager.backgroundSoundID) { oldValue, newValue in
                                notificationManager.updateBackgroundSoundPreference(to: newValue)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        do {
                            try authManager.signOut()
                        } catch {
                            print("Error signing out: \\(error)")
                        }
                    }) {
                        Text("Keluar (Logout)")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Selesai") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                notificationManager.requestPermission()
            }
        }
    }
}
