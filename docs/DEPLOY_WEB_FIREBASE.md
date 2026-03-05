# WildPulse App Web Deploy (Firebase Hosting)

This deploys the Flutter dashboard as a web app and points it to your backend API.

## Prerequisites

- Flutter installed
- Node.js installed
- Firebase CLI installed:

```bash
npm install -g firebase-tools
```

## Build Web App

Use your deployed backend URL:

```bash
flutter clean
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://<your-backend-domain>/api
```

## Initialize Firebase Hosting

From this project root:

```bash
firebase login
firebase init hosting
```

Choose:

- Existing Firebase project
- Public directory: `build/web`
- Single-page app rewrite: `Yes`
- Do not overwrite existing `index.html` if prompted

## Deploy

```bash
firebase deploy --only hosting
```

## Verify

- Open your Hosting URL
- Confirm tabs load data from:
  - `/api/dashboard/overview`
  - `/api/images`
  - `/api/needs-review`

