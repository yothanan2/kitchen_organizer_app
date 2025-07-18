Project Handoff & Core Directives
This document provides the complete context for the Kitchen Organizer Flutter project. Please review this entire file carefully before proceeding with any task.

1.  **Core Directives (CRITICAL)**
    *   (This section remains unchanged)

2.  **Project Overview**
    *   (This section remains unchanged)

3.  **Technical Stack**
    *   (This section remains unchanged)

4.  **Current Project Status**
    The project is in a stable, runnable state. We have successfully resolved critical deployment and authentication issues, and the live web application at `unmercato1.web.app` is now loading and operational. The backend connection via Firebase is confirmed to be working correctly. All recent changes have been pushed to the `fix/login-issue` branch.

5.  **Recent Accomplishments:**
    *   **Refactored Dish & Component Management:**
        *   Separated the UI and logic for creating Dishes (now just a name and status) and Components (which contain recipes, ingredients, etc.).
        *   Implemented functionality to add, remove, and reorder Components within a Dish.
        *   Added a "Notes" field to both Dishes and Components for additional details.
    *   **Improved Component Deletion:**
        *   Fixed a bug that prevented the deletion of in-use components.
        *   The error message now helpfully lists the specific Dishes a Component is linked to, allowing admins to resolve the dependency.
    *   **Resolved Firestore Index Issue:** Created the necessary Firestore index to support the component deletion query.
    *   **Fixed Critical Deployment Bug:** Resolved the "blank page" issue by updating the web initialization script (`index.html`) and correcting the Firebase options configuration.
    *   **Resolved Authentication:** Fixed the "invalid email or password" error by updating the project with the correct Firebase API key.
    *   **Established Stable Deployment:** The application is now successfully building and deploying to Firebase Hosting.
    *   Refactored the data model to group requisition items into a single document with a trackable status.
    *   Built the UI for the kitchen and butcher to manage this new requisition workflow.
    *   Implemented a responsive, state-aware blinking notification bell.
    *   Verified the low-stock items feature on the kitchen dashboard.

6.  **Established Workflow**
    *   (This section remains unchanged)

7.  **Core Application Workflow: The "Connected Loop"**
    The entire application operates on a core principle: **everything is connected**. Actions in one part of the system must trigger appropriate reactions in others. The primary workflow loop is as follows:

    *   **1. Data Hierarchy (Admin Defined):**
        *   **Dish:** A high-level menu item (e.g., "Pasta with Mussels"). It is primarily a name/container.
        *   **Components:** A Dish is composed of one or more "Components." These are the reusable building blocks or prep-tasks (e.g., "Boil pasta," "Make creme sauce").
        *   **Component Recipe:** The actual recipe, containing ingredients and steps, is attached to the *Component*.
        *   **Stock/Inventory:** All ingredients listed in a Component's recipe must be drawn from the central inventory. Each inventory item is mapped to a specific **Supplier**.

    *   **2. Mise en Place (Prep Lists):** The daily workflow starts with the "mise en place" prep lists. These lists are generated from the active Dishes selected by the admin. The tasks on the list are the **Components** required for those dishes.

    *   **3. Inventory Consumption:** When a staff member completes a prep task (a Component), they consume the specified ingredients from the inventory. The system must track this consumption in real-time.

    *   **4. Low-Stock Monitoring:** Every item in the inventory has a pre-defined minimum stock level. After any consumption, the system checks if the new quantity has fallen below this minimum.

    *   **5. Automated Ordering:** If an item is below its minimum stock level, the system automatically adds it to a "Daily Ordering Suggestion" list, grouped by its assigned **Supplier**.

    This interconnectedness is the most critical aspect of the application's logic. The full chain is: **Dish -> Components -> Recipe -> Inventory/Stock -> Ordering -> Supplier**. All new features or modifications must respect and maintain this workflow.

8.  **Current Project Notes & Open Tasks**
    *   Continue building out the admin dashboard functionality.