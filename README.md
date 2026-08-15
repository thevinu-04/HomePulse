# 🏠 HomePulse – Smart Home Monitoring & Control System

HomePulse is a smart home monitoring and control system developed for the  
**SCS 3311 – Mobile Application Design & Development Mini Project**.

The system uses a **Flutter mobile application, Firebase Realtime Database, and a web-based hardware simulator** to monitor and control smart-home devices across multiple floors in real time.

## Key Features

- Firebase email/password authentication
- Multi-floor smart home management
- Grid-based floor and device representation
- Real-time device monitoring and control
- ON, OFF, ERROR and DISCONNECTED device states
- Multi-switch device support
- Scheduled lighting
- Safety-critical device auto cutoff
- Mock security camera monitoring
- Device alerts and usage reports
- Real-time synchronization with the hardware simulator

## Tech Stack

- **Mobile:** Flutter, Dart
- **Database:** Firebase Realtime Database
- **Authentication:** Firebase Authentication
- **Simulator:** HTML, CSS, JavaScript
- **Version Control:** Git & GitHub

## Run the Application

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --release
```

APK location:

```text
build/app/outputs/flutter-apk/app-release.apk
```
