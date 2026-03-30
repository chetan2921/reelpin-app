<div align="center">
  <img src="https://via.placeholder.com/150/190019/FBE4D8?text=ReelPin" width="150" alt="ReelPin Logo"/>

  # ReelPin 📍

  **The AI-Powered Instagram Reel Knowledge Base & Map**

  *Share any Instagram Reel to ReelPin, and instantly extract, map, and categorize the locations inside it using AI.*
</div>

---

## 🌟 Overview

**ReelPin** is a full-stack smart application that turns your messy pile of "Saved" Instagram Reels into an actionable, visual map of real-world places. Found a cool restaurant, study spot, or hiking trail on Instagram? 

Just **Share → ReelPin**. The app's backend natively processes the reel, uses LLMs to extract exact locations, auto-geocodes them, and instantly drops a pin onto your private interactive map without you ever opening the app.

## ✨ Key Features

- **Native Share Integration:** Uses deep OS-level sharing (`receive_sharing_intent`) so you can send reels directly from the Instagram App via the native Share Sheet.
- **AI Audio/Text Processing:** A FastAPI backend receives the reel, extracts the transcript/caption, and uses machine learning to isolate entities (restaurants, parks, cities).
- **Auto-Geocoding:** Connects to the **Google Maps Geocoding API** to translate mentioned locations into exact Coordinates instantly.
- **Beautiful Interactive Map:** View all your saved locations dynamically on a completely custom-styled Google Map. 
- **Real-Time Cross-App Sync:** Seamlessly loads pins in the background so they are ready the second you switch from Instagram to ReelPin.
- **State-of-the-Art Theming:** A strictly adhered, handcrafted 6-color minimalist dark palette featuring glassmorphism and subtle micro-animations.

---

## 🛠️ Technology Stack

### Frontend (Mobile App)
- **Framework:** Flutter (Dart)
- **State Management:** Provider Architecture
- **Maps:** `google_maps_flutter` integrating custom JSON REST styles.
- **Deep Linking:** `receive_sharing_intent` for accepting payload intents.

### Backend (Server)
- **Framework:** FastAPI (Python)
- **Geocoding:** Google Maps Platform API
- **AI Processing:** Uses semantic extraction patterns on reel transcripts.
- **Database:** Supabase (PostgreSQL)

---

## 🎨 Design & Aesthetics

ReelPin uses a strict 6-color palette to guarantee a premium, ultra-modern dark experience without looking cheap or overly colorful.

| Name         | Hex Code  | Role                                      |
| ------------ | --------- | ----------------------------------------- |
| **Plum**     | `#190019` | Deepest Scaffold Foundation (Solid)       |
| **Indigo**   | `#2B124C` | Translucent Cards, Bottom Sheets, Modals  |
| **Amethyst** | `#522B5B` | Primary Accents, Active Map Pins, Alerts  |
| **Mauve**    | `#854F6C` | Secondary Chips, Subtle Gradients         |
| **Dusty**    | `#DFB6B2` | Progress Indicators, Glow Outlines        |
| **Cream**    | `#FBE4D8` | Typography, App Borders, Glass Highlights |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (`>=3.0.0`)
- Android Studio / Xcode
- Google Maps API Key (With Maps SDK & Geocoding SDK enabled)
- A running instance of the **ReelPin FastAPI Backend**

### 1. Configure the Backend URL
Ensure the Flutter app points to your backend. Open `lib/config/api_config.dart` and update the local IP address for physical testing, or your production URL for live builds:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8000/api/v1';
```

### 2. Configure Google Maps
Add your Google Maps API Key securely to your Android setup.
Create `android/local.properties` (this file should be `.gitignore`'d!) and add:
```properties
MAPS_API_KEY=AIzaSy...your_key_here
```

### 3. Build & Run
Connect a physical device (Emulators do not support the Instagram app to test Share Intents effectively) and run:
```bash
flutter clean
flutter pub get
flutter build apk # To generate a permanent release build
flutter run       # To run in debug mode
```

---

## 📱 Usage
1. Open the **Instagram** app and find a Reel.
2. Tap **Share** (The paper airplane icon).
3. Scroll and select **ReelPin** in your OS Share Sheet.
4. ReelPin wakes up, extracts the URL, grabs the precise Google Map location via the backend, and drops a pin on your map immediately. 

---
<div align="center">
  <i>Designed with focus, built for explorers.</i>
</div>
