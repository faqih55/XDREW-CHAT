import Foundation
import UserNotifications
import AVFoundation

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var hasPermission = false
    @Published var isNotificationsEnabled: Bool = true
    @Published var inAppSoundID: UInt32 = 1007 // Default message sound inside chat
    @Published var backgroundSoundID: UInt32 = 1000 // Default message sound outside chat
    @Published var inAppSoundEnabled: Bool = true
    @Published var backgroundSoundEnabled: Bool = true
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        
        // Load saved sound preferences
        if let savedInAppSound = UserDefaults.standard.object(forKey: "in_app_notification_sound") as? UInt32 {
            self.inAppSoundID = savedInAppSound
        }
        if let savedNotificationsEnabled = UserDefaults.standard.object(forKey: "is_notifications_enabled") as? Bool {
            self.isNotificationsEnabled = savedNotificationsEnabled
        }
        if let savedBgSound = UserDefaults.standard.object(forKey: "background_notification_sound") as? UInt32 {
            self.backgroundSoundID = savedBgSound
        }
        if let savedInAppEnabled = UserDefaults.standard.object(forKey: "in_app_notification_enabled") as? Bool {
            self.inAppSoundEnabled = savedInAppEnabled
        }
        if let savedBgEnabled = UserDefaults.standard.object(forKey: "background_notification_enabled") as? Bool {
            self.backgroundSoundEnabled = savedBgEnabled
        }
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.hasPermission = granted
            }
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleLocalNotification(title: String, body: String, roomId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["roomId": roomId]
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func playInAppSound() {
        if inAppSoundEnabled {
            AudioServicesPlaySystemSound(inAppSoundID)
        }
    }
    
    func playBackgroundSound() {
        if backgroundSoundEnabled {
            AudioServicesPlaySystemSound(backgroundSoundID)
        }
    }
    
    func updateInAppSoundPreference(to soundID: UInt32) {
        inAppSoundID = soundID
        UserDefaults.standard.set(soundID, forKey: "in_app_notification_sound")
        AudioServicesPlaySystemSound(soundID)
    }
    
    func updateBackgroundSoundPreference(to soundID: UInt32) {
        backgroundSoundID = soundID
        UserDefaults.standard.set(soundID, forKey: "background_notification_sound")
        AudioServicesPlaySystemSound(soundID)
    }
    
    func toggleInAppSound(enabled: Bool) {
        inAppSoundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "in_app_notification_enabled")
    }
    
    func toggleBackgroundSound(enabled: Bool) {
        backgroundSoundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "background_notification_enabled")
    }
    
    func toggleNotifications(enabled: Bool) {
        isNotificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "is_notifications_enabled")
        if enabled {
            requestPermission()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard isNotificationsEnabled else {
            completionHandler([])
            return
        }
        
        // Play custom system sound since UNNotificationSound can only use bundled files
        playBackgroundSound()
        // Show banner and badge, but omit .sound because we played a custom one
        completionHandler([.banner, .badge])
    }
}
