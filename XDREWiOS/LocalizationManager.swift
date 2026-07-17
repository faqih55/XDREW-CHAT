import Foundation
import SwiftUI

// MARK: - App Language Enum
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case indonesian = "id"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .indonesian: return "Bahasa Indonesia"
        }
    }
}

// MARK: - Localized Dictionary
struct Localized {
    static func string(key: String, lang: AppLanguage) -> String {
        let dict: [AppLanguage: [String: String]] = [
            .english: [
                "search_placeholder": "Search...",
                "filter_all": "All",
                "filter_friends": "Friends",
                "filter_groups": "Groups",
                "filter_bot": "Bot",
                "preferences": "PREFERENCES",
                "account_support": "ACCOUNT & SUPPORT",
                "notifications": "Notifications",
                "dark_mode": "Dark Mode",
                "language": "Language",
                "privacy_security": "Privacy & Security",
                "help_support": "Help & Support",
                "about": "About",
                "logout": "Log Out",
                "online": "Online",
                "offline": "Offline",
                "type_message": "Type a message...",
                "start_new_chat": "Start New Chat",
                "tab_friends": "Friends",
                "tab_bot": "Bot",
                "tab_group": "Group",
                "group_name": "GROUP NAME",
                "group_name_placeholder": "E.g. Dev Team, Alpha Squad...",
                "choose_members": "CHOOSE GROUP MEMBERS",
                "create_group": "Create Group Chat",
                "no_users": "No other users registered",
                "edit_profile": "Edit Profile",
                "username_label": "USERNAME",
                "choose_avatar": "CHOOSE POPULAR AVATAR",
                "custom_avatar": "OR ENTER CUSTOM AVATAR URL",
                "save": "Save",
                "cancel": "Cancel",
                "avatar_preview": "Avatar Preview",
                "active_account": "Active Account",
                "select_language": "Select Language",
                "done": "Done",
                "cancel_btn": "Cancel",
                "replying_to": "Replying to message"
            ],
            .indonesian: [
                "search_placeholder": "Cari obrolan...",
                "filter_all": "Semua",
                "filter_friends": "Teman",
                "filter_groups": "Grup",
                "filter_bot": "Bot",
                "preferences": "PENGATURAN",
                "account_support": "AKUN & DUKUNGAN",
                "notifications": "Notifikasi",
                "dark_mode": "Mode Gelap",
                "language": "Bahasa",
                "privacy_security": "Privasi & Keamanan",
                "help_support": "Bantuan & Dukungan",
                "about": "Tentang",
                "logout": "Keluar dari Akun",
                "online": "Online",
                "offline": "Offline",
                "type_message": "Tulis pesan...",
                "start_new_chat": "Mulai Chat Baru",
                "tab_friends": "Teman",
                "tab_bot": "Bot",
                "tab_group": "Grup",
                "group_name": "NAMA GRUP",
                "group_name_placeholder": "Contoh: Dev Team, Alpha Squad...",
                "choose_members": "PILIH ANGGOTA GRUP",
                "create_group": "Buat Grup Obrolan",
                "no_users": "Tidak ada pengguna lain terdaftar",
                "edit_profile": "Edit Profil",
                "username_label": "NAMA PENGGUNA",
                "choose_avatar": "PILIH AVATAR POPULER",
                "custom_avatar": "ATAU MASUKKAN URL FOTO KUSTOM",
                "save": "Simpan",
                "cancel": "Batal",
                "avatar_preview": "Pratinjau Avatar",
                "active_account": "Akun Aktif",
                "select_language": "Pilih Bahasa",
                "done": "Selesai",
                "cancel_btn": "Batal",
                "replying_to": "Membalas pesan"
            ]
        ]
        return dict[lang]?[key] ?? key
    }
}
