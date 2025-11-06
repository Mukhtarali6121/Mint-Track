# Mint-Track

Expense Tracker App

## About

Mint-Track is a comprehensive expense tracking application built with Flutter. It helps users manage their finances by tracking expenses, income, accounts, and financial goals.

## Features

### Core Features
- 📊 **Transaction Management**: Add, edit, and delete income and expense transactions
- 💰 **Account Management**: Multiple account support with balance tracking
- 📈 **Charts & Analytics**: Visual representation of your spending patterns
- 🎯 **Goals Tracking**: Set and track saving goals and spending limits
- 🔍 **Search**: Search through your transactions
- 💱 **Multi-Currency Support**: Support for various currencies
- ☁️ **Cloud Sync**: Backup and sync data to Firebase Firestore

### Goals Feature
- **Saving Goals**: Track income toward specific savings targets
- **Spending Limits**: Monitor and limit expenses within budgets
- **Automatic Progress**: Real-time progress calculation from transactions
- **Visual Feedback**: Progress bars and completion celebrations
- **Flexible Configuration**: Optional target amounts, deadlines, and filters

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Firebase project setup

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Mukhtarali6121/Mint-Track.git
cd Mint-Track
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update Firebase configuration in `lib/firebase_options.dart`

4. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── common/              # Shared utilities and storage
├── models/              # Data models
├── presentation/        # UI screens
│   ├── screens/         # Main screens
│   └── login/           # Authentication screens
├── services/            # Business logic services
├── theme/               # App theming
└── widgets/             # Reusable widgets
```

## Documentation

- [Goals Feature Summary](./GOALS_FEATURE_SUMMARY.md) - Complete goals feature documentation
- [Goals Executive Summary](./GOALS_FEATURE_EXECUTIVE_SUMMARY.md) - VC pitch version
- [Goal Types Explanation](./GOAL_TYPES_EXPLANATION.md) - Detailed explanation of goal types

## Technologies Used

- **Flutter**: Cross-platform mobile framework
- **Firebase**: Authentication and cloud storage
- **Hive**: Local database for offline support
- **Provider**: State management
- **Firestore**: Cloud database
- **Charts**: Data visualization

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is private and proprietary.

## Contact

For questions or support, please open an issue on GitHub.
