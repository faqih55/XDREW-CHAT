import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct Speaker: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    var isSpeaking: Bool
    let color: Color
}

struct VoiceSpaceView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var agoraManager = AgoraManager()
    @State private var isMuted = false
    
    // Abstract local random speaking logic for mock users
    @State private var mockSpeakingStates: [UInt: Bool] = [:]
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var speakers: [Speaker] {
        var list = [Speaker]()
        
        // Local User
        list.append(Speaker(name: "You", initials: "ME", isSpeaking: !isMuted, color: .blue))
        
        // Remote Users
        for uid in agoraManager.remoteUserIDs {
            list.append(Speaker(name: "User \(uid)", initials: "U", isSpeaking: mockSpeakingStates[uid] ?? false, color: .purple))
        }
        
        // Fallback mock users if no one is here (for UI showcase)
        if agoraManager.remoteUserIDs.isEmpty {
            list.append(Speaker(name: "Dr. Elena", initials: "EL", isSpeaking: mockSpeakingStates[1] ?? false, color: .green))
            list.append(Speaker(name: "Nexus Bot", initials: "NX", isSpeaking: mockSpeakingStates[2] ?? true, color: .purple))
            list.append(Speaker(name: "Alpha 1", initials: "A1", isSpeaking: mockSpeakingStates[3] ?? false, color: .orange))
        }
        
        return list
    }
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.94, blue: 0.98).ignoresSafeArea()
            
            // Abstract animated background
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -100, y: -200)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center) {
                        Text("Global Voice Space")
                            .font(.headline)
                            .foregroundColor(.black)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                    }
                }
                .padding()
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
                
                // Grid Speaker Layout
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(speakers) { speaker in
                            SpeakerView(speaker: speaker)
                        }
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 20)
                }
                
                // Bottom Controls
                HStack(spacing: 40) {
                    Button(action: {
                        // Settings Action
                        #if canImport(UIKit)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        #endif
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
                    }
                    
                    Button(action: {
                        #if canImport(UIKit)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isMuted.toggle()
                        }
                    }) {
                        Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding(20)
                            .background(isMuted ? Color.gray : Color(red: 0.45, green: 0.35, blue: 0.9))
                            .clipShape(Circle())
                            .shadow(color: (isMuted ? Color.gray : Color(red: 0.45, green: 0.35, blue: 0.9)).opacity(0.4), radius: 10, y: 5)
                    }
                    
                    Button(action: {
                        #if canImport(UIKit)
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        #endif
                        agoraManager.leaveChannel()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .shadow(color: Color.red.opacity(0.4), radius: 10, y: 5)
                    }
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: -5)
            }
        }
        .onAppear {
            agoraManager.joinChannel(channelName: "global_space", isVideo: false)
        }
        .onDisappear {
            agoraManager.leaveChannel()
        }
        .onReceive(timer) { _ in
            // Randomly toggle speaking states for mock users
            for i in 1...3 {
                if Bool.random() {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        mockSpeakingStates[UInt(i)] = !(mockSpeakingStates[UInt(i)] ?? false)
                    }
                }
            }
        }
    }
}

struct SpeakerView: View {
    let speaker: Speaker
    @State private var waveScale: CGFloat = 1.0
    @State private var waveOpacity: Double = 0.8
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if speaker.isSpeaking {
                    Circle()
                        .stroke(speaker.color.opacity(0.5), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(waveScale)
                        .opacity(waveOpacity)
                        .onAppear {
                            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                waveScale = 1.5
                                waveOpacity = 0.0
                            }
                        }
                }
                
                Circle()
                    .fill(LinearGradient(colors: [speaker.color.opacity(0.3), speaker.color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle().stroke(speaker.isSpeaking ? speaker.color : Color.white.opacity(0.1), lineWidth: speaker.isSpeaking ? 3 : 1)
                    )
                    .shadow(color: speaker.isSpeaking ? speaker.color.opacity(0.5) : .clear, radius: 10)
                
                Text(speaker.initials)
                    .font(.title2)
                    .bold()
                    .foregroundColor(speaker.color)
            }
            
            Text(speaker.name)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
