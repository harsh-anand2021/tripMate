# Tripmate

Tripmate is a Flutter app with a FastAPI backend that uses facial recognition (via InsightFace) and geofencing for driver check-in/check-out functionality.

## Features

- OTP Login via Telegram
- Selfie capture and facial verification
- Geofence-based check-in/out
- Trip number tracking
- PostgreSQL backend

## How to Run

### Flutter Frontend

```bash
cd frontend_folder
flutter pub get
flutter run


###Python Backend


cd backend_folder
pip install -r requirements.txt
uvicorn main:app --reload

#### Make sure to configure your .env file for Telegram tokens, DB URL, etc.
