# VOLARIS X — Complete Setup Guide

---

## PART 1: GitHub Repository

1. Go to github.com → New repository → name it `volaris-x`
2. Clone or download this project folder into it
3. Push these files to GitHub:
   - server.js
   - package.json
   - .gitignore
   - public/ (index.html, manifest.json)

Do NOT push: serviceAccountKey.json, node_modules/

---

## PART 2: Firebase Project

1. Go to console.firebase.google.com
2. Create new project → name it "VolarisX"
3. Disable Google Analytics → Create project
4. Add Android app → package name: com.volarix.monitor
5. Download google-services.json (needed in Part 4)
6. Go to Project Settings → Service accounts → Generate new private key
   → Save as serviceAccountKey.json (DO NOT commit to GitHub)

---

## PART 3: Render.com Deployment

1. Go to dashboard.render.com → New → Web Service
2. Connect your volaris-x GitHub repo
3. Settings:
   - Build Command: npm install
   - Start Command: node server.js
4. Add Environment Variables:
   - FIREBASE_SERVICE_ACCOUNT → paste the ENTIRE contents of serviceAccountKey.json
5. Deploy → note your Render URL (e.g. https://volaris-x.onrender.com)

---

## PART 4: Android App (Capacitor)

### Setup project
```
mkdir volaris-app && cd volaris-app
npm init -y
npm install @capacitor/core @capacitor/cli @capacitor/android
npm install @capacitor-firebase/messaging
npx cap init "Volaris X" "com.volarix.monitor" --web-dir=www
```

### Copy web files
Copy everything from public/ into the www/ folder inside volaris-app/

### Update capacitor.config.json
Replace YOUR-VOLARIX-SERVER with your actual Render URL

### Add Android
```
npx cap add android
```

### Add google-services.json
Copy google-services.json (from Firebase) into:
android/app/google-services.json

### Add alert sound
Copy your alert_tone.wav into:
android/app/src/main/res/raw/alert_tone.wav

### Replace MainActivity.java
Copy MainActivity.java (provided) to:
android/app/src/main/java/com/volarix/monitor/MainActivity.java

### Set app icon
- In Android Studio → right-click res → New → Image Asset
- Foreground: your Volaris X logo PNG
- Background color: #050508
- Finish

### Build
```
npx cap sync
```
Open Android Studio → Run on device

---

## PART 5: MT5 EA

1. Copy VOLARIS_X_MONITOR.mq5 to your MT5 Experts folder
2. Open MetaEditor → compile it
3. Attach to any chart
4. Set InpWebSocketUrl to your Render URL
   e.g. wss://volaris-x.onrender.com
5. Allow WebRequest for your URL in MT5 Tools → Options → Expert Advisors

---

## PART 6: Per-Symbol Alert Preferences

Users control their own preferences locally in the app:
- Open the app → Settings tab
- Toggle any index on/off
- Changes save instantly on their device
- Each user's preferences are sent to the server on subscribe
  so the server only pushes alerts for their enabled symbols

---

## Testing a signal

Once deployed, test by sending a POST to your Render URL:

PowerShell:
```
Invoke-WebRequest -Uri https://your-server.onrender.com/ -Method POST -ContentType 'application/json' -Body '{"type":"signal","symbol":"VOL75","timeframe":"M30","trade_type":"BUY"}'
```

You should receive the notification with the alert tone on your phone.

---

## Notes

- FCM tokens are stored in memory on Render's free tier
  → users re-subscribe when server restarts (free tier sleeps after inactivity)
  → consider Render paid plan for production use

- Each user's per-symbol preferences are synced to the server on subscribe
  and whenever they toggle a symbol in the Settings tab

- The server does NOT send removal notifications (clean UX)
  only new signals trigger alerts
