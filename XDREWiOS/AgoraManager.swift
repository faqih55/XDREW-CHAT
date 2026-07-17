import Foundation
import AgoraRtcKit
import SwiftUI

class AgoraManager: NSObject, ObservableObject {
    static let appID = "76c7542fe5e24da9a6611b370205557f"
    
    @Published var remoteUserIDs: [UInt] = []
    @Published var isJoined: Bool = false
    @Published var isMuted: Bool = false
    
    var engine: AgoraRtcEngineKit?
    
    override init() {
        super.init()
        setupEngine()
    }
    
    func setupEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = AgoraManager.appID
        engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
    }
    
    func joinChannel(channelName: String, isVideo: Bool) {
        if isVideo {
            engine?.enableVideo()
            engine?.startPreview()
        } else {
            engine?.disableVideo()
        }
        
        let option = AgoraRtcChannelMediaOptions()
        option.clientRoleType = .broadcaster
        option.publishMicrophoneTrack = true
        option.publishCameraTrack = isVideo
        option.autoSubscribeAudio = true
        
        let tempToken = "007eJxTYIh4K1D95tNx46SHd7+0N1tsPuRlIbHDa/bOZXNUJ0eIK1sqMJibJZubmhilpZqmGpmkJFommpkZGiYZmxsYGZiampqnab6KyGoIZGRYsVOQkZEBAkF8DoaS1OKSovz8XAYGAAHgIRI="
        let testChannel = "testroom"
        let result = engine?.joinChannel(byToken: tempToken, channelId: testChannel, uid: 0, mediaOptions: option)
        if result == 0 {
            print("Successfully requested to join channel \(testChannel)")
        } else {
            print("Failed to join channel with error code: \(result ?? -1)")
        }
    }
    
    func leaveChannel() {
        engine?.leaveChannel(nil)
        engine?.stopPreview()
        isJoined = false
        remoteUserIDs.removeAll()
        print("Left channel")
    }
    
    func toggleMute() {
        isMuted.toggle()
        engine?.muteLocalAudioStream(isMuted)
    }
    
    func switchCamera() {
        engine?.switchCamera()
    }
}

extension AgoraManager: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            self.isJoined = true
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            if !self.remoteUserIDs.contains(uid) {
                self.remoteUserIDs.append(uid)
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        DispatchQueue.main.async {
            self.remoteUserIDs.removeAll(where: { $0 == uid })
        }
    }
}
