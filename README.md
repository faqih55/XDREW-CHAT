<div align="center">

[![FAQIH55 Header](header.svg?v=2)](https://github.com/faqih55)

<a href="https://github.com/faqih55">
  <img src="https://readme-typing-svg.demolab.com?font=Share+Tech+Mono&weight=700&size=20&duration=3000&pause=800&color=00FFFF&center=true&vCenter=true&width=750&lines=%E2%97%88+Hello%2C+World!+I+am+faqih55+%E2%97%88;%F0%9F%8D%8E+Building+iOS+apps+with+SwiftUI;%E2%9A%A1+Fullstack+Developer+%7C+Laravel+%2B+PHP;%F0%9F%92%99+Cross-Platform+with+Flutter+%26+Dart;%F0%9F%8C%90+Web+Craftsman+%7C+HTML+%2B+CSS+%2B+JS;%F0%9F%9A%80+Turning+ideas+into+digital+reality;%E2%9C%A8+Welcome+to+my+digital+universe" alt="Typing SVG" />
</a>

<br/>

![STATUS](https://img.shields.io/badge/%E2%97%88_STATUS-ONLINE-00ffff?style=for-the-badge&labelColor=070b14)
![iOS](https://img.shields.io/badge/%E2%9A%A1_iOS-DEVELOPER-b700ff?style=for-the-badge&logo=apple&logoColor=white&labelColor=070b14)
![FULLSTACK](https://img.shields.io/badge/%F0%9F%8C%90_FULLSTACK-ENGINEER-ff0080?style=for-the-badge&logo=stackblitz&logoColor=white&labelColor=070b14)
![INDONESIA](https://img.shields.io/badge/%F0%9F%87%AE%F0%9F%87%A9_BASED-INDONESIA-ffd700?style=for-the-badge&labelColor=070b14)

</div>

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
