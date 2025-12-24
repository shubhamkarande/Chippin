# Chippin - Share Bills. Stay Chill. 💰

A cross-platform finance splitter app that lets friends split bills, scan receipts, track balances, and settle up — even offline.

![Flutter](https://img.shields.io/badge/Flutter-3.6+-02569B?logo=flutter)
![Django](https://img.shields.io/badge/Django-5.0+-092E20?logo=django)
![Firebase](https://img.shields.io/badge/Firebase-Auth-FFCA28?logo=firebase)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

### Core Features

- **👥 Group Expense Sharing** - Create groups and invite friends via QR code or link
- **💸 Flexible Splitting** - Equal, percentage, or exact amount splits
- **📷 Receipt Scanning** - OCR-powered receipt scanning using Google ML Kit
- **📊 Balance Tracking** - Real-time "who owes whom" calculations
- **🔄 Offline-First** - Works without internet, syncs when online
- **📱 Cross-Platform** - Android and iOS support

### Additional Features

- **📈 Analytics** - Monthly spend charts and category breakdown
- **📤 Export** - PDF and CSV export for expense reports
- **💱 Multi-Currency** - INR, USD, EUR, GBP support
- **🌙 Dark Mode** - Beautiful dark and light themes
- **⚡ Quick Presets** - Fast entry for common expenses (Uber, Zomato, etc.)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
├─────────────────────────────────────────────────────────────┤
│  Riverpod State  │  SQLite Local DB  │  Firebase Auth       │
├─────────────────────────────────────────────────────────────┤
│                    Sync Engine                               │
│           (Offline-first with conflict resolution)           │
├─────────────────────────────────────────────────────────────┤
│                   Django REST Backend                        │
│              (Optional - for cloud sync)                     │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
Chippin/
├── lib/                          # Flutter app source
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   ├── screens/                  # UI screens
│   ├── widgets/                  # Reusable widgets
│   ├── services/                 # Business logic
│   ├── state/                    # Riverpod providers
│   ├── local_db/                 # SQLite database
│   └── theme/                    # App theming
├── backend/                      # Django REST API
│   ├── core/                     # Django settings
│   └── api/                      # API endpoints
├── android/                      # Android config
├── ios/                          # iOS config
└── test/                         # Tests
```

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.6.0 or higher
- **Python** 3.11+ (for backend)
- **Firebase Account** (for authentication)
- **Android Studio** or **VS Code** with Flutter extensions

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/chippin.git
cd chippin
```

### 2. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Email/Password Authentication**
3. Add Android app and download `google-services.json`
4. Add iOS app and download `GoogleService-Info.plist`
5. Place files in respective platform directories:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

### 3. Run Flutter App

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### 4. Backend Setup (Optional)

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or: venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env
# Edit .env with your settings

# Run migrations
python manage.py migrate

# Start server
python manage.py runserver
```

## 📱 App Screens

| Screen | Description |
|--------|-------------|
| **Welcome** | Sign up, login, or continue as guest |
| **Groups List** | View and manage expense groups |
| **Group Detail** | Expenses, balances, and activity tabs |
| **Add Expense** | Manual entry with split options |
| **Scan Receipt** | Camera-based OCR scanning |
| **Balance Summary** | Detailed who-owes-whom view |
| **Analytics** | Spending charts and insights |
| **Export** | PDF/CSV export options |

## 🧪 Running Tests

### Flutter Tests

```bash
flutter test
```

### Backend Tests

```bash
cd backend
python manage.py test api
```

## 🔧 Configuration

### Environment Variables (Backend)

Create a `.env` file in the `backend` directory:

```env
DEBUG=True
SECRET_KEY=your-secret-key
DATABASE_URL=sqlite:///db.sqlite3
FIREBASE_CREDENTIALS_PATH=path/to/firebase-credentials.json
ALLOWED_HOSTS=localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=http://localhost:3000
```

### API Base URL (Mobile)

Update the API URL in `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'http://your-backend-url/api';
```

## 📊 Database Schema

### Local SQLite (Mobile)

- `users` - User accounts
- `groups` - Expense groups
- `group_members` - Group memberships
- `expenses` - Expense records
- `expense_splits` - Split details
- `settlements` - Settlement records
- `pending_sync` - Offline sync queue

### Backend (PostgreSQL/SQLite)

- Same schema with additional sync metadata

## 🔐 Security

- Firebase Authentication for secure login
- JWT tokens for API authentication
- Sensitive data encrypted locally
- No passwords stored in plain text

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - Cross-platform framework
- [Django REST Framework](https://www.django-rest-framework.org) - Backend API
- [Firebase](https://firebase.google.com) - Authentication
- [Google ML Kit](https://developers.google.com/ml-kit) - OCR
- [fl_chart](https://pub.dev/packages/fl_chart) - Charts

---

Made with ❤️ by the Chippin Team
