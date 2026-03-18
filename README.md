# LearnY

A premium Flutter client for Tsinghua University Web Learning (网络学堂).

## Architecture

```
lib/
├── core/
│   ├── api/          # thu-learn-lib Dart port (100% method coverage)
│   ├── design/       # Design system (colors, typography, theme)
│   ├── router/       # GoRouter with ShellRoute
│   └── shell/        # 4-tab navigation shell
├── features/
│   ├── auth/         # Login (WebView SSO)
│   ├── home/         # Smart aggregation home
│   ├── assignments/  # Assignment dashboard + list
│   ├── courses/      # Course grid + details
│   └── profile/      # Settings & profile
└── main.dart
```

## Tech Stack

| Category | Library |
|----------|---------|
| Framework | Flutter 3.x + Dart 3.11 |
| State | Riverpod 2 + freezed |
| Network | Dio 5 + cookie_jar |
| Database | Drift (SQLite) |
| Routing | GoRouter + ShellRoute |
| UI | Material 3 + google_fonts + flutter_animate |

## Getting Started

```bash
flutter pub get
flutter run
```

## License

MIT
