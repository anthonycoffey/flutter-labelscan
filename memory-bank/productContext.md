-# Product Context: Flutter LabelScan

## 1. Problem Statement

*   Shoppers often lose track of their total spending while adding items to their cart in physical stores, leading to potential budget overruns or surprises at the checkout counter. Manually tracking costs is tedious and prone to errors.

## 2. Proposed Solution

*   Flutter LabelScan allows shoppers to scan product price labels using their phone's camera during their shopping trip. The app utilizes OCR technology to automatically extract the price from the label image. It maintains a running subtotal of scanned items, calculates estimated taxes, and displays the estimated final cost in real-time, providing immediate feedback on spending and helping users stay within their budget.

## 3. User Experience Goals

*   **Simplicity:** The app should be straightforward and easy to use, even for non-technical users.
*   **Speed:** Scanning and information retrieval should be fast and efficient.
*   **Reliability:** Scanning should be accurate under various conditions.
*   **Clarity:** Displayed information should be clear and easy to understand.

## 4. Key Features (User Perspective)

*   **Real-time Price Scanning:** Use the phone's camera to scan price labels.
*   **OCR Price Extraction:** Automatically reads the price from the scanned label.
*   **Running Total:** Displays the subtotal of scanned items.
*   **Tax Calculation:** Estimates and adds applicable taxes.
*   **Final Cost Estimate:** Shows the estimated total cost.
*   **Shopping History (Saved Lists):** Ability to save, view, and delete shopping lists (Implemented using Firestore).
*   **Offline Mode:** Core scanning and totaling functionality works without internet.
*   **Image Input:** Ability to upload label images or scan in real-time via the camera.
*   **User Profile:** Basic user account management with avatar upload.

## 5. Planned Enhancements

*   **Toolbar Branding:** Enhance the application's toolbar to incorporate branding elements.
*   **Home Screen Interactivity:** Improve the user experience on the home screen, specifically making the "Save List" and "Clear List" actions more intuitive (e.g., using a jump menu with text labels).
