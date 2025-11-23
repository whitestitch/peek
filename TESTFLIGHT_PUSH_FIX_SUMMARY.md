# TestFlight Push Notification Fix Summary

## 🔥 Root Cause
**APNs Environment Mismatch**: Entitlements had `production` but TestFlight requires `development`.

## ✅ What Was Fixed

### 1. Created Separate Entitlements Files
- `Runner-Debug.entitlements` → `development` (for TestFlight/Debug)
- `Runner-Release.entitlements` → `production` (for App Store)

### 2. Added Debug Logging
- FCM token registration logging
- Background message handler logging
- Platform and build mode detection

### 3. Diagnostic Script
- Created `ios/check_push_setup.sh` to verify configuration

## 📋 Manual Steps Required

### Step 1: Configure Xcode
```bash
cd /Users/carlobruno/development/peek
open ios/Runner.xcworkspace
```

1. Select **Runner** target → **Signing & Capabilities**
2. Add **Push Notifications** capability if not present
3. For **Debug & Profile** configurations:
   - Build Settings → Code Signing Entitlements
   - Set to: `Runner/Runner-Debug.entitlements`
4. For **Release** configuration:
   - Build Settings → Code Signing Entitlements
   - Set to: `Runner/Runner-Release.entitlements`

### Step 2: Verify Firebase Console
Visit: https://console.firebase.google.com/project/peekio-db/settings/cloudmessaging/

Ensure you have EITHER:
- ✅ APNs Authentication Key (.p8) - Recommended, works for both dev & prod
- ✅ OR both Development & Production SSL Certificates

### Step 3: Clean & Archive
```bash
# In Xcode:
Product → Clean Build Folder (⌘⇧K)
Product → Archive
```

## 🧪 Testing Checklist

### After Installing TestFlight Build:

1. **Connect device to Mac via USB**
2. **Open Console.app** → Select device
3. **Filter for "peek" or "FCM"**
4. **Launch app and login**
5. **Check for logs:**
   ```
   ✅ "didRegisterForRemoteNotificationsWithDeviceToken"
   ✅ "🔐 [FCM TOKEN DEBUG]"
   ✅ FCM token saved to Firestore
   ```

6. **Send test notification from Firebase Console or Cloud Function**
7. **Close app completely (swipe up)**
8. **Wait for notification**
9. **Check Console.app for:**
   ```
   ✅ "📨 [BACKGROUND MESSAGE HANDLER]"
   ✅ Message ID and data
   ```

## 🔍 Common Issues & Solutions

### Issue: No APNs token in logs
**Solution**:
- Verify Push Notifications capability is enabled in Xcode
- Check entitlements file is set correctly for build configuration
- Rebuild app completely

### Issue: FCM token null
**Solution**:
- Verify GoogleService-Info.plist is included in target
- Check Firebase project has APNs certificate/key uploaded
- Delete app, reinstall from TestFlight

### Issue: Notification arrives but doesn't show
**Solution**:
- Backend must send `notification` field (not just `data`)
- Backend must include `apns` configuration with `alert`
- See `FCM_PAYLOAD_EXAMPLE.json` for correct structure

### Issue: Works in foreground, not background
**Solution**:
- This was the entitlements issue - fixed by using development APNs
- Verify `UIBackgroundModes` includes `remote-notification` in Info.plist ✅
- Verify `FirebaseMessaging.onBackgroundMessage` is registered ✅

## 📱 Backend Notification Payload

Your Cloud Functions must send:
```json
{
  "notification": {  // ← REQUIRED for background display
    "title": "New Peek Request! 👀",
    "body": "Someone wants to see what you're up to"
  },
  "data": {
    "type": "peek_request_received",
    "requestId": "abc123"
  },
  "apns": {  // ← REQUIRED for iOS
    "headers": {
      "apns-priority": "10"
    },
    "payload": {
      "aps": {
        "content-available": 1,
        "sound": "default"
      }
    }
  }
}
```

See `FCM_PAYLOAD_EXAMPLE.json` for complete structure.

## ⚠️ Remember

- **TestFlight = Development APNs**
- **App Store = Production APNs**
- **Both need separate certificates OR use one .p8 Auth Key for both**

## 🎯 Expected Result

After fix:
- ✅ Notifications show when app is **closed**
- ✅ Notifications show when app is **background**
- ✅ Notifications show when app is **foreground** (handled by Flutter)
- ✅ Tapping notification opens app with correct data

## 📞 If Still Not Working

1. Check Console.app logs for errors
2. Verify FCM token is being saved to Firestore
3. Test notification from Firebase Console → Cloud Messaging → "Send test message"
4. Verify backend is sending correct payload structure
5. Check Firebase Console → Cloud Messaging → "Apple app configuration"

