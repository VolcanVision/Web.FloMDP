# FloMDP User Guide

Welcome to FloMDP!

## Overview
FloMDP is a Flutter-based application designed to streamline your workflow. This guide provides a quick start and essential usage instructions.

## Getting Started
1. **Install Dependencies**
   - Run `flutter pub get` in the project root to install all required packages.
2. **Running the App**
   - For Android: `flutter run -d android`
   - For iOS: `flutter run -d ios`
   - For Web: `flutter run -d chrome`
   - For Desktop: `flutter run -d windows` / `macos` / `linux`

## Project Structure
- `lib/` - Main Dart code (screens, widgets, services, etc.)
- `assets/` - Images and other static assets
- `test/` - Test files
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` - Platform-specific code

## Authentication
- Configure authentication in `lib/auth/config/` as needed.

## Database
- Database schema is in `schema.sql`.
- Supabase functions and migrations are in `supabase/`.

## Theming
- Customize app appearance in `lib/theme/`.

## Testing
- Run tests with `flutter test`.

## Troubleshooting
- If you encounter issues, try `flutter clean` and then `flutter pub get`.
- Check the README.md for more details.

## Support
For more information, refer to the README.md or contact the project maintainer.
