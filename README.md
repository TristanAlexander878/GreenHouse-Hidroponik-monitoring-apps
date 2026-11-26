# 🌱 GreenHouse Hidroponik — Smart Monitoring & Control

A real-time IoT monitoring dashboard built with **Flutter** and **Firebase Realtime Database** for an automated hydroponic greenhouse system. Tracks nutrient levels and environmental conditions live from microcontroller sensors.

---

## 🏗️ System Architecture

    [Sensors: pH, EC, Temp] ──► [Microcontroller (ESP32/Arduino)] ──► [Firebase Realtime DB] ──► [Flutter App]
                                           │
                                           ▼
                                [Automated Irrigation / Actuators]

## ✨ Key Features
* **Live Telemetry:** Real-time syncing of **pH**, **Electrical Conductivity (EC)**, and **Water/Ambient Temperature** with zero manual refresh.
* **Automated Irrigation Logic:** Microcontroller triggers pumps/valves based on threshold rules while reporting state changes to the app.
* **Threshold Alerts:** Visual indicators when nutrient concentration or pH drifts outside optimal crop ranges.

---

## 🛠️ Tech Stack
* **Mobile App:** Flutter, Dart
* **Backend / Cloud:** Firebase Realtime Database (`firebase.json`, `firestore.rules`)
* **Hardware / IoT:** ESP32 / Microcontroller, pH Sensor, TDS/EC Sensor, Temperature Sensor

---

## 🗄️ Firebase Database Structure
The app listens to the following JSON schema in Firebase:

    {
      "greenhouse": {
        "sensors": {
          "ph": 6.2,
          "ec": 1.4,
          "temperature": 26.5
        },
        "irrigation": {
          "pump_status": false,
          "auto_mode": true
        }
      }
    }

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (`3.50.1` / Dart `3.14.0`)
* Firebase CLI & configured `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)

### Installation
1. **Clone the repository**

       git clone [https://github.com/TristanAlexander878/GreenHouse-Hidroponik-monitoring-apps.git](https://github.com/TristanAlexander878/GreenHouse-Hidroponik-monitoring-apps.git)
       cd GreenHouse-Hidroponik-monitoring-apps

2. **Configure Firebase**
   * Place your `google-services.json` inside `android/app/`.
3. **Install dependencies & run**

       flutter pub get
       flutter run

---

## 📸 Screenshots 
| Mobile Dashboard |
| :---: | :---: |
| <img width="381" height="848" alt="image" src="https://github.com/user-attachments/assets/2ae121e3-233c-4517-b427-7e0ca655c6ec" />
