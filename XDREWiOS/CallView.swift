import SwiftUI
import AgoraRtcKit

struct CallView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var agoraManager = AgoraManager()
    
    let isVideo: Bool
    let channelName: String
    let targetUserName: String
    
    // Animation states
    @State private var isPulsing = false
    @State private var hasSomeoneJoined = false
    
    var body: some View {
        ZStack {
            // Background Layer
            if isVideo, let remoteUid = agoraManager.remoteUserIDs.first {
                // Show remote video as background
                AgoraVideoView(manager: agoraManager, uid: remoteUid, isLocal: false)
                    .ignoresSafeArea()
            } else {
                // Gradient or Avatar Blur Background
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Pulsing Background Effect (when ringing/connecting)
                if !agoraManager.isJoined || agoraManager.remoteUserIDs.isEmpty {
                    Circle()
                        .fill(Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.15))
                        .frame(width: 300, height: 300)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: false), value: isPulsing)
                        .onAppear { isPulsing = true }
                }
            }
            
            // Local PiP Video
            if isVideo {
                VStack {
                    HStack {
                        Spacer()
                        AgoraVideoView(manager: agoraManager, uid: 0, isLocal: true)
                            .frame(width: 110, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                            .padding(.top, 40)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
            
            // Overlay Controls
            VStack {
                // Header (Caller Info)
                if !isVideo || agoraManager.remoteUserIDs.isEmpty {
                    VStack(spacing: 16) {
                        // Avatar placeholder
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                                .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.5), radius: 15, y: 5)
                            
                            Text(String(targetUserName.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 60)
                        
                        Text(targetUserName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        
                        Text(agoraManager.isJoined ? (agoraManager.remoteUserIDs.isEmpty ? "Waiting for others..." : "00:00") : "Connecting...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Bottom Controls (Glassmorphism)
                HStack(spacing: 32) {
                    // Mute
                    controlButton(
                        icon: agoraManager.isMuted ? "mic.slash.fill" : "mic.fill",
                        backgroundColor: agoraManager.isMuted ? Color.white : Color.white.opacity(0.2),
                        iconColor: agoraManager.isMuted ? .black : .white
                    ) {
                        agoraManager.toggleMute()
                    }
                    
                    // End Call
                    controlButton(
                        icon: "phone.down.fill",
                        backgroundColor: Color.red,
                        iconColor: .white,
                        size: 72,
                        iconSize: 32
                    ) {
                        endCall()
                    }
                    
                    // Switch Camera (only for video)
                    if isVideo {
                        controlButton(
                            icon: "camera.rotate.fill",
                            backgroundColor: Color.white.opacity(0.2),
                            iconColor: .white
                        ) {
                            agoraManager.switchCamera()
                        }
                    } else {
                        // Speaker toggle placeholder for audio
                        controlButton(
                            icon: "speaker.wave.3.fill",
                            backgroundColor: Color.white.opacity(0.2),
                            iconColor: .white
                        ) {
                            // Toggle speaker
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 40)
                        .fill(Color.black.opacity(0.2))
                        .background(BlurView(style: .systemThinMaterialDark).clipShape(RoundedRectangle(cornerRadius: 40)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 40)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            agoraManager.joinChannel(channelName: channelName, isVideo: isVideo)
        }
        .onDisappear {
            agoraManager.leaveChannel()
        }
        .onChange(of: agoraManager.remoteUserIDs) { oldUids, newUids in
            if !newUids.isEmpty {
                hasSomeoneJoined = true
            } else if hasSomeoneJoined {
                endCall()
            }
        }
    }
    
    private func endCall() {
        agoraManager.leaveChannel()
        presentationMode.wrappedValue.dismiss()
    }
    
    // Custom button builder for controls
    private func controlButton(icon: String, backgroundColor: Color, iconColor: Color, size: CGFloat = 60, iconSize: CGFloat = 24, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 5, y: 3)
        }
    }
}

struct AgoraVideoView: UIViewRepresentable {
    var manager: AgoraManager
    var uid: UInt
    var isLocal: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let canvas = AgoraRtcVideoCanvas()
        canvas.view = view
        canvas.renderMode = .hidden
        canvas.uid = uid
        
        if isLocal {
            manager.engine?.setupLocalVideo(canvas)
        } else {
            manager.engine?.setupRemoteVideo(canvas)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// Blur effect wrapper for SwiftUI
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
