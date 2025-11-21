# Meiso

A minimalist task management app built on the Nostr protocol.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Zapstore](https://img.shields.io/badge/Get%20on-Zapstore-purple)](https://zapstore.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev/)
[![Nostr](https://img.shields.io/badge/Protocol-Nostr-purple)](https://nostr.com/)

---

## 📱 About

**Meiso** (瞑想) is a simple, privacy-focused task management app inspired by TeuxDeux's clean design. Built on the Nostr protocol with end-to-end NIP-44 encryption, your tasks are synced across devices without any central server.

## ✨ Features

- **Three-Column Layout**: Today / Tomorrow / Someday organization
- **Recurring Tasks**: Daily, weekly, monthly, yearly patterns with flexible intervals
- **Personal Lists**: Create custom lists to organize tasks by category
- **Nostr Sync**: Multi-device synchronization via Nostr relays
- **Privacy First**: NIP-44 end-to-end encryption for all tasks
- **Amber Integration**: Secure key management with Amber signer support
- **Dark Mode**: Easy on the eyes day and night
- **Multi-Language**: English, Japanese, Spanish support
- **Drag & Drop**: Intuitive task reordering
- **Pull to Refresh**: Quick sync with a simple gesture

## 📸 Screenshots

<p align="center">
  <img src="screenshots/01_home_screen.png" width="250" alt="Home Screen"/>
  <img src="screenshots/02_add_task.png" width="250" alt="Add Task"/>
  <img src="screenshots/03_someday_lists.png" width="250" alt="Someday Lists"/>
</p>

## 📥 Installation

### Zapstore (Recommended)
Download Meiso from [Zapstore](https://zapstore.dev/) - the Nostr-native app store.

### Build from Source
```bash
# Clone the repository
git clone https://github.com/higedamc/meiso.git
cd meiso

# Install dependencies
fvm flutter pub get

# Build for Android
./generate.sh
fvm flutter build apk --release
```

## 🛠️ Tech Stack

- **Frontend**: Flutter 3.x with Riverpod state management
- **Backend Logic**: Rust with flutter_rust_bridge
- **Protocol**: Nostr (NIP-44 encryption, Kind 30078)
- **Storage**: Local-first with Hive, synced via Nostr relays
- **Architecture**: Feature-based Clean Architecture

## 📚 Documentation

- **[Development Roadmap](docs/MLS_BETA_ROADMAP.md)** - Upcoming features and MLS group lists
- **[Clean Architecture Guide](docs/REFACTOR_CLEAN_ARCHITECTURE_STRATEGY.md)** - Architecture details
- **[Release Guide](docs/ZAPSTORE_RELEASE_GUIDE_JA.md)** - How to publish to Zapstore (Japanese)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 👤 Author

**Kohei Otani**  
Nostr: `npub16lrdq99ng2q4hg5ufre5f8j0qpealp8544vq4ctn2wqyrf4tk6uqn8mfeq`

---

**⚡ Powered by Nostr ⚡**
