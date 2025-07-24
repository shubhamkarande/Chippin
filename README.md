# Chippin - Share Bills. Stay Chill.

A mobile-first finance splitting app built with Flutter that helps users auto-split bills, scan receipts using OCR, export summaries, and sync their data securely.

## Features

### Core Features
- **Group Creation**: Create groups and add members via email or invite codes
- **Auto Bill Splitting**: Split bills equally or with custom amounts
- **OCR Receipt Scanner**: Upload or capture receipt images for automatic parsing
- **Offline-First**: Local SQLite storage with cloud sync capability
- **Export Options**: Export group expenses as PDF or CSV
- **Real-time Balances**: Track who owes what in each group

### Tech Stack
- **Frontend**: Flutter (cross-platform)
- **Local Database**: SQLite
- **State Management**: Provider
- **Image Processing**: Image Picker + OCR ready
- **UI Design**: Material Design 3 with custom theme

## Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio / VS Code
- Android/iOS device or emulator

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd chippin
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── database/          # SQLite database helper
│   ├── models/           # Data models (Group, Member, Expense)
│   ├── providers/        # State management
│   └── theme/           # App theme and styling
└── screens/             # UI screens
    ├── home_screen.dart
    ├── create_group_screen.dart
    ├── group_detail_screen.dart
    └── add_expense_screen.dart
```

## Roadmap

### Phase 1 (Current)
- ✅ Basic group and expense management
- ✅ Local SQLite storage
- ✅ Clean UI with Material Design 3
- 🔄 OCR receipt processing
- 🔄 PDF/CSV export functionality

### Phase 2 (Planned)
- Firebase Authentication
- Cloud sync with Firestore
- Push notifications
- Advanced splitting options
- Receipt image storage

### Phase 3 (Future)
- Django REST API backend
- Multi-currency support
- Expense categories
- Analytics and insights
- Web dashboard

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
