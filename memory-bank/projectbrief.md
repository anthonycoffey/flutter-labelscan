# Project Brief: Flutter LabelScan

## 1. Project Goal

* **Primary Objective:** To create a mobile application using Flutter that helps shoppers track their shopping cart costs in real-time by scanning price labels.
* **Secondary Objectives:** Provide estimated tax calculations, allow users to save shopping history, ensure basic functionality works offline.

## 2. Core Requirements

*   **Price Label Scanning:** Implement functionality to capture images of price labels using the device camera.
*   **OCR Price Extraction:** Utilize OCR (via a backend service) to automatically extract price data from the scanned label image.
*   **Real-time Calculation:** Maintain a running subtotal, calculate estimated taxes, and display the estimated final cost.
*   **Platform:** Target both iOS and Android platforms using Flutter.
*   **User Interface:** Provide a clean, intuitive, and responsive user interface for scanning and viewing totals.
*   **Authentication:** Allow users to sign in (e.g., via Google) to potentially save history.
*   **Backend Integration:** Communicate with a Python/Flask backend for OCR processing.
*   **Shopping History:** Allow users to save and view past shopping trips (requires authentication).

## 3. Scope

*   **In Scope:**
    *   Camera integration for capturing price labels.
    *   Sending images to a backend Flask API for OCR.
    *   Displaying extracted price.
    *   Calculating and displaying running subtotal, estimated tax, and final cost.
    *   Firebase Authentication (Google Sign-In).
    *   Saving shopping trip data (items, total) to Cloud Firestore (linked to authenticated user).
    *   Basic offline capability for scanning/totaling (assuming OCR is backend-dependent, offline might just queue items or use cached data if available).
*   **Out of Scope:** [Define features explicitly excluded for now.]
    *   Scanning barcodes or QR codes (focus is on price labels via OCR).
    *   Detailed product information lookup (beyond price).
    *   Budgeting features or spending analysis.
    *   Price comparisons or deals.
    *   Offline OCR processing within the app.
    *   Inventory management features.
    *   [Add more as defined]

## 4. Target Audience

*   Shoppers in physical retail stores who want to actively track their spending and stay within budget during their shopping trip.

## 5. Success Metrics

*   [How will project success be measured? - e.g., Accuracy of OCR price extraction, speed of scan-to-update cycle, user retention, positive app store reviews focusing on budget management.]
