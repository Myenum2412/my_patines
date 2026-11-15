# MyPatines

A Flutter login app styled to match the My Clinics login page (`https://myclinic.myenum.in/login`) without Google authentication.

## Features

- Native Flutter login UI (no WebView)
- Email and password fields with show/hide password toggle
- "Forgot password?" and "Create your clinic" links
- "Login" action with basic form validation
- Terms of Service and Privacy Policy notice
- No "Continue with Google" / social sign-in section

## Project structure

- `lib/main.dart` - app entry point and login screen UI
- `test/widget_test.dart` - widget test verifying login UI and absence of Google auth

## Getting started

```bash
cd my_patines
flutter pub get
```

### Firebase (FlutterFire) setup

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=my-patines
```

Initialize Firebase in `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// ...

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

Then run the app:

```bash
flutter run
```

## Test

```bash
flutter test
```
