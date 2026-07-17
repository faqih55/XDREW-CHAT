# XDREW-CHAT IOS 17+

A modern, real-time iOS communication application built with Swift and SwiftUI. XDREW-CHAT provides a comprehensive suite of features for seamless messaging and audio/video calling.

## 🚀 Features

- **Real-time Chatting**: Fast and reliable instant messaging powered by Firebase.
- **Voice & Video Calls**: High-quality, low-latency audio and video communication utilizing the Agora SDK.
- **Authentication**: Secure user login and registration flows.
- **Audio Recording**: Built-in voice message recording capabilities.
- **Location Sharing**: Share your location easily with the integrated location picker.
- **Voice Spaces**: Dedicated spaces for group voice interactions.
- **Push Notifications**: Stay updated with real-time alerts for incoming messages and calls.
- **Localization Support**: Built-in architecture for multi-language support.

## 🛠 Tech Stack

- **Platform**: iOS 17.0+
- **UI Framework**: SwiftUI
- **Backend/Database**: [Firebase](https://firebase.google.com/) (SDK ~> 10.20.0)
- **Real-Time Communication**: [Agora SDK](https://www.agora.io/en/) (AgoraRtcEngine_iOS ~> 4.6.2)
- **Project Generation**: XcodeGen (`project.yml`)

## ⚙️ Project Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/faqih55/XDREW-CHAT.git
   cd XDREW-CHAT
   ```

2. **Generate Xcode Project**
   Since the project uses `project.yml`, you will need [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` file.
   ```bash
   # Install xcodegen if you haven't already (requires Homebrew)
   brew install xcodegen
   
   # Generate the project
   xcodegen generate
   ```

3. **Configure Firebase**
   - Add your `GoogleService-Info.plist` file to the root/target directory of the project.

4. **Open and Run**
   - Open `XDREWiOS.xcodeproj`.
   - Wait for Swift Package Manager (SPM) to resolve dependencies (Firebase & Agora).
   - Select your target device or simulator and hit **Run** (Cmd + R).

## 📂 Project Structure

- `XDREWiOS/` - Main application source code (SwiftUI Views, Managers, Coordinators).
- `project.yml` - XcodeGen configuration file detailing targets and SPM dependencies.
- `add_*.rb` - Various Ruby helper scripts for project configuration.

## 📄 License

This project is open-source and available under the MIT License.
