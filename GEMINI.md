# Project Handoff: Kitchen Organizer Application

## 1. Project Overview
The project is a comprehensive Kitchen Organizer application designed for a restaurant. It manages inventory, recipes, and daily operational tasks for various staff roles.

### Core Functionalities

* **User Management**: A robust system with roles (Admin, Kitchen Staff, Floor Staff, Butcher) and an admin approval workflow for new accounts.
* **Inventory Management**: Full CRUD (Create, Read, Update, Delete) functionality for inventory items, including associated categories, units, suppliers, and storage locations.
* **Dish & Recipe System**: An advanced system for creating dishes that can be composed of both individual ingredients and linkable "Components" (sub-recipes). This allows for complex, multi-level recipe construction.
* **Daily Operations**:
    * **Daily Notes**: A real-time "Post-it note" feature for admins to communicate important daily information to all staff dashboards.
    * **Prep Lists**: A full workflow for generating daily prep lists from dishes, which staff can check off as they complete their "Mise en Place."
    * **Butcher Requisitions**: A system where Admins curate a list of items for the Butcher to request. The Butcher then submits a single, grouped requisition for all needed items.
    * **Kitchen Requisition Management**: A dedicated screen for Kitchen Staff to view incoming requisitions, check off prepared items, and update the requisition status.
    * **Floor Staff Requests**: A system for Floor Staff to make urgent requests for the next day.
* **Notifications**: A real-time, in-app notification system. A bell icon in the `AppBar` blinks to alert staff to new and pending tasks. The color of the blink indicates the status of the request (e.g., requested vs. prepared).
* **Reporting & Analytics**: A dedicated analytics screen for reporting on "Most Used Ingredients" and a "Task Champions" leaderboard using interactive charts.
* **Purchase Orders**: A system for generating and emailing purchase orders to suppliers using Cloud Functions.

---

## 2. Technical Stack
* **Framework**: Flutter (Dart) for a cross-platform web application.
* **Backend**: Firebase (Firestore, Firebase Authentication, Firebase Cloud Functions).
* **State Management**: `flutter_riverpod`.
* **Key Packages**: `cloud_firestore`, `firebase_auth`, `cloud_functions`, `rxdart`, `fl_chart`.

---

## 3. Current Project Status
The project is in a stable, runnable state. We have recently completed a major feature implementation: a new, robust, multi-stage requisition system.

**Recent Accomplishments:**
* Refactored the butcher requisition process to group items into a single request document with a trackable status (`requested`, `prepared`, `received`).
* Built a new screen for the kitchen to view and manage these grouped requisitions.
* Built a confirmation screen for the butcher to mark items as "received."
* Implemented a three-stage (Red/Yellow/Green) blinking notification bell in the `AppBar` to provide real-time updates on requisition statuses.
* Made the Butcher Dashboard UI fully responsive to work on both wide and narrow screens.
* Resolved a platform-specific crash on mobile related to Firebase Auth persistence.

---

## 4. Our Method for Making Changes (Very Important)
We have an established workflow that must be followed for all changes:

1.  **Git Backup First**: Before any major change, I (the user) will make a Git commit to create a safe restore point. You will provide the command sequence after each successful task.
2.  **One Task at a Time**: We focus on a single, specific bug or feature.
3.  **Holistic Analysis**: Before providing code, you (the AI) must perform a "global search" across all project files to identify every part of the app affected by the proposed change.
4.  **Provide Complete Code**: You will provide the complete, corrected code for all affected files at once. I will not accept partial snippets (with the exception of `providers.dart`, for which you will give specific line-by-line instructions).
5.  **Confirmation**: I will implement the changes and confirm that the task is complete and error-free before we move on.

---

## 5. Current Project Notes
The following are open tasks and ideas for future implementation:

* The "Today" button on the kitchen dashboard is not doing anything.
* We need to work on the low-stock items feature on the kitchen dashboard.
* Implement SMS notifications, including phone number verification during registration and an opt-in choice for users.
* When requested items are prepared and ready for pickup, send an SMS notice.
* **SMS Notification Issue**: The Twilio Firebase Extension is consistently returning a "A 'From' or 'MessagingServiceSid' parameter is required" error (code 21603) despite re-configuring the `TWILIO_PHONE_NUMBER`. This needs further investigation into Twilio account settings or extension reinstallation.