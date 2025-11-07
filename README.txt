AI Study Helper - Flutter prototype
App name: AI Study Helper
Package name: com.himanshuraj.aistudyhelper
Primary color: Blue (developer choice)
OpenAI: real API support included. Enter your OpenAI API key in Settings after first install.
How to run:
1. Install Flutter SDK and set up Android toolchain.
2. Open this project folder in Android Studio or VSCode.
3. Run: flutter pub get
4. Run: flutter run (on device or emulator)

Notes:
- This is a prototype. It saves notes locally using SharedPreferences.
- Quiz generation calls OpenAI. Prompts ask for JSON formatted MCQs. Parsing may fail for some outputs.
- Replace package name in Android files if needed before publishing.
- Do not hardcode API keys. Users must enter their own keys.
