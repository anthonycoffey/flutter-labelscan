# Active Context: Flutter LabelScan

*Updated: 4/16/2025, 3:00 AM (America/Chicago)*

## 1. Current Focus

*   Updating the Memory Bank files (`activeContext.md`, `progress.md`) following the addition of the "Clear All Lists" button to the `SavedListsScreen` AppBar.
*   **Goal:** Ensure Memory Bank accurately reflects the latest UI modifications.

## 2. Recent Changes & Decisions

*   **SavedListsScreen AppBar UI Update:**
    *   Modified `lib/screens/saved_lists_screen.dart`.
    *   Added an `IconButton` (`Icons.delete_forever_outlined`, colored red) to the `AppBar` actions.
    *   This button triggers the existing `_deleteAllLists` function (which includes a confirmation dialog) to clear all saved lists for the user from Firestore.
*   **(Previous) HomeScreen AppBar UI Update (Color-Coding):**
    *   Modified `lib/screens/home_screen.dart`.
    *   Applied conditional coloring to the "Save List" and "Clear All Items" `IconButton`s in the `AppBar`.
    *   Save button (`Icons.save_as`) is now `Colors.green` when active.
    *   Clear button (`Icons.delete_sweep_outlined`) is now `Colors.red` when active.
    *   Buttons revert to the default color when disabled (based on `homeState`).
*   **(Previous) HomeScreen AppBar UI Update (Layout):**
    *   Modified `lib/screens/home_screen.dart`.
    *   Removed the `PopupMenuButton` (previously used for Save/Clear actions) from the `AppBar`.
    *   Added dedicated `IconButton` widgets directly to the `AppBar` actions for "Save List" and "Clear All Items".
    *   These buttons reuse the existing dialog functions (`_showSaveListDialog`, `_showClearConfirmationDialog`) and have appropriate enable/disable logic based on the `homeState`.
*   **(Previous) List Details Screen UI Update:**
    *   Modified `lib/screens/list_details_screen.dart` to display calculated tax percentage in the format `Taxes (X.XX%)`.
    *   Removed trailing colons from "Subtotal", "Taxes", and "Total" labels in the receipt footer section of the same screen.

## 3. Next Steps

*   [List the next 1-3 concrete actions to be taken.]
    1.  Review and update `memory-bank/progress.md` to reflect the `SavedListsScreen` AppBar UI change.
    2.  Finalize this Memory Bank update session.
    3.  *(Deferred)* Address outstanding questions/placeholders in Memory Bank files (Git Workflow, Error Handling, Commit Messages, Out of Scope, Success Metrics).

## 4. Active Considerations & Questions

*   **Git Workflow:** `systemPatterns.md` describes a Feature Branch workflow, while `techContext.md` mentions Trunk-based. Need to confirm the intended strategy or update `techContext.md` to match the more detailed description in `systemPatterns.md`. (Assuming Feature Branch for now).
*   **OCR Technology:** Confirmed backend uses Google Cloud Vision API and potentially Gemini API (as stated in `systemPatterns.md`). References to ML Kit/Tesseract in other files need removal.
*   **Placeholders:** Still need clarification on placeholders in `techContext.md` (Commit Messages), `systemPatterns.md` (Error Handling), and `projectbrief.md` (Out of Scope, Success Metrics).

## 5. Important Patterns & Preferences (Learnings)

*   **Memory Bank:** Strict adherence to maintaining the Memory Bank is crucial. All core files must exist and be updated regularly.
*   **Initial Setup:** The current focus is on establishing the foundational documentation before significant coding begins.

## 6. Project Insights

*   [Any high-level observations or learnings about the project so far.]
