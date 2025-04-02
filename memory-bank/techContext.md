# Technical Context: Flutter LabelScan

## 1. Core Technologies

*   **Framework:** Flutter (3.29.2)
*   **Language:** Dart (3.7.2)
*   **Target Platforms:** iOS, Android

## 2. Development Environment

*   **IDE:** VS Code
*   **Version Control:** Git
*   **Build Tool:** Flutter CLI (`flutter build`, `flutter run`)

## 3. Key Dependencies / Packages

*   **State Management:** `setState` (based on `StatefulWidget` usage)
*   **Navigation:** `Navigator` (Imperative routing, e.g., `Navigator.push`, `Navigator.pop`)
*   **Scanning:** `camera: ^0.11.1` (Used for image capture, potentially for scanning?)
*   **HTTP Client (if applicable):** `http: ^1.3.0`
*   **Local Storage (if applicable):** `path_provider: ^2.1.5` (Used for finding file system paths)
*   **Firebase (if applicable):** `firebase_core: ^3.13.0`, `firebase_auth: ^5.5.2`, `google_sign_in: ^6.2.1`, `cloud_firestore: ^5.6.6`, `firebase_storage: ^12.4.5`
*   **Other Key Packages:** `image_picker: ^1.1.2`, `path: ^1.9.1`, `http_parser: ^4.0.2`, `mime: ^1.0.5`, `intl: ^0.20.2`, `cupertino_icons: ^1.0.8`
*   **Linting/Formatting:** `flutter_lints: ^5.0.0`

*(Add other significant dependencies as needed)*

## 4. Technical Constraints & Considerations

*   **Platform Differences:** Any specific considerations for iOS vs. Android (e.g., permissions handling).
*   **Performance:** Target performance goals (e.g., smooth animations, fast scan detection).
*   **Offline Support:** Requirements for functioning without an internet connection.
*   **Security:** Any specific security requirements (e.g., data encryption).

## 5. Tool Usage & Conventions

*   **Code Style:** Effective Dart (Flutter/Dart), PEP 8 (Python/Flask). Enforced by `flutter_lints` for Dart.
*   **Commit Messages:** Not strictly enforced (hobby project).
*   **Branching Strategy:** Trunk-based development (main/master initially).
*   **Testing:** `flutter_test` (Unit/Widget testing). No integration testing currently planned.
