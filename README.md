# 🎵 uMusic - Premium Experience

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/GetX-6366F1?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Premium-Design-8A2BE2?style=for-the-badge" />
</p>

uMusic is a high-fidelity music streaming and downloader application built with Flutter, designed to provide a seamless, ad-free, and premium auditory journey.

---

## ✨ Key Features

### 🎬 Advanced Video Playback
- **High-Performance Player**: Powered by `pod_player` with automatic fallback logic to ensure videos play in any network condition.
- **Rich Meta-Data**: View full video descriptions with a sleek "Show More/Less" toggle.
- **Background Mode**: Seamlessly switch to audio-only background playback, complete with notification controls.

### ⏬ Precision Downloader
- **Quality Control**: Select exactly the resolution (up to 4K) or format (Audio/Video) you want before downloading.
- **No More Auto-Downloads**: You are in control of your storage and data.
- **Reliable Extraction**: Uses `youtube_explode_dart` for resilient metadata and stream extraction.

### 📁 Intelligent Library Management
- **Smart Filtering**: Organize your local downloads with dedicated tabs for **All**, **Videos**, and **Music**.
- **Local Audio Support**: Play your downloaded music in the background with full media session integration.
- **Glassmorphism UI**: A stunning, modern interface featuring smooth animations and high-end design tokens.

### 🌐 Connectivity & Content
- **Offline Mode**: Automatically detects connectivity status and provides quick access to your local library when offline.
- **Subscription Sync**: Login to YouTube to sync your subscriptions and discover new music effortlessly.
- **Detection from Clipboard**: Automatically detects YouTube links in your clipboard for instant downloading.

---

## 🛠️ State-of-the-Art Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (v3.x)
- **State Management**: [GetX](https://pub.dev/packages/get) - Providing snappy navigation and reactive UI.
- **Audio Engine**: [just_audio](https://pub.dev/packages/just_audio) & [just_audio_background](https://pub.dev/packages/just_audio_background).
- **Video Engine**: [pod_player](https://pub.dev/packages/pod_player) - Premium player controls and customization.
- **Metadata**: [youtube_explode_dart](https://pub.dev/packages/youtube_explode_dart).
- **Design System**: Atomic design with Glassmorphism, Google Fonts (`Outfit`), and custom `UDesign` tokens.

---

## 🚀 Recent Updates (v1.2.0)
- **Enhanced Player**: Improved initialization success rate with dual-stage parsing.
- **Social Integration**: Functional Like, Share, and Save actions with real-time feedback.
- **Offline Resiliance**: New center-screen offline state with quick library navigation.
- **Library Tabs**: Precision filtering for localized content management.

---

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK (v3.19.0+ recommended)
- Java 17+ (for Android builds)

### Quick Run
```bash
# Clone the repository
git clone https://github.com/bakhtidaoud/umusic.git

# Navigate to project
cd umusic

# Install dependencies
flutter pub get

# Run on your device
flutter run
```

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <strong>Crafted with ❤️ for Music Lovers</strong><br>
  Designed by the uMusic Team
</p>
