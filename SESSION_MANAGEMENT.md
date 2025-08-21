# 🔒 Peek Session Management System

## Overview

The Peek Session Management System prevents users from receiving multiple peek requests simultaneously by implementing a robust session-lock mechanism. This ensures consistent UX and prevents notification conflicts during active peek flows.

## 🎯 Key Features

### ✅ **Session State Tracking**
- **Real-time session state** across the entire peek flow
- **Persistent storage** using SharedPreferences and Firestore
- **Automatic cleanup** of stale sessions (30-minute timeout)

### ✅ **Session Lock Mechanism**
- **Blocks new peek requests** when user is in active session
- **Suppresses FCM notifications** for users in sessions
- **Prevents duplicate dialogs** and conflicting UI states

### ✅ **Complete Flow Coverage**
- **Request → Capture → Reaction** flow fully protected
- **Session state updates** at each transition point
- **Automatic session ending** when flow completes

## 🏗 Architecture

### **Core Components**

#### 1. **SessionManager** (`lib/core/session_manager.dart`)
- **Central session controller** managing all session states
- **Local persistence** using SharedPreferences
- **Firestore synchronization** for Cloud Functions access
- **Session validation** and cleanup logic

#### 2. **Session Providers** (`lib/core/providers/session_providers.dart`)
- **Riverpod providers** for reactive session state
- **Global session state** accessible throughout the app
- **Real-time updates** when session state changes

#### 3. **Cloud Functions Integration** (`functions/index.js`)
- **Server-side session checking** before sending notifications
- **Automatic notification suppression** for active sessions
- **Stale session cleanup** on the server side

### **Session States**

```dart
// Available session states
'idle'              // No active session
'waiting_response'  // User accepted peek, waiting for photo
'photo_capture'     // User is taking/uploading photo
'viewing_image'     // User is viewing received image
'reaction'          // User is reacting to image
```

## 🔄 Session Flow

### **1. Session Start**
```dart
// When user accepts a peek request
await sessionManager.startSession(requestId, 'waiting_response');
```

### **2. State Transitions**
```dart
// Photo capture mode
await sessionManager.updateSessionState('photo_capture');

// Viewing image
await sessionManager.updateSessionState('viewing_image');

// Reaction mode
await sessionManager.updateSessionState('reaction');
```

### **3. Session End**
```dart
// When flow completes (reaction submitted, skipped, etc.)
await sessionManager.endSession();
```

## 🚫 Notification Suppression

### **Client-Side Blocking**
- **PeekDialogManager** checks `canReceivePeeksProvider`
- **Blocks dialog display** if user is in active session
- **Prevents UI conflicts** and duplicate dialogs

### **Server-Side Blocking**
- **Cloud Functions** check `activePeekSession` in Firestore
- **Suppresses FCM notifications** for active sessions
- **Automatic cleanup** of stale sessions

## 📱 Integration Points

### **PeekDialogManager**
```dart
// Check session state before showing dialog
final canReceivePeeks = ref.read(canReceivePeeksProvider);
if (!canReceivePeeks) {
  debugPrint('User is in active session, blocking new peek request');
  return;
}
```

### **PhotoCapturePage**
```dart
// Update session state when entering capture mode
void _updateSessionState() {
  final sessionManager = ref.read(sessionManagerProvider);
  if (widget.mode == 'response') {
    sessionManager.updateSessionState('photo_capture');
  } else {
    sessionManager.startSession(widget.requestId, 'photo_capture');
  }
}
```

### **PeekImageView**
```dart
// Update session state when viewing image
void _updateSessionState() {
  final sessionManager = ref.read(sessionManagerProvider);
  sessionManager.updateSessionState('viewing_image');
}
```

### **ReactionScreen**
```dart
// End session when flow completes
Future<void> _endSession() async {
  final sessionManager = ref.read(sessionManagerProvider);
  await sessionManager.endSession();
  // Navigate home...
}
```

## 🔧 Configuration

### **Session Timeout**
```dart
// Maximum session duration (30 minutes)
static const Duration _maxSessionDuration = Duration(minutes: 30);
```

### **Firestore Fields**
```json
{
  "activePeekSession": {
    "isActive": true,
    "requestId": "peek_request_id",
    "state": "photo_capture",
    "startTime": "2024-01-01T00:00:00Z",
    "lastUpdated": "2024-01-01T00:00:00Z"
  }
}
```

## 🧪 Testing

### **Debug Information**
- **Debug panel** on homepage (only in debug mode)
- **Real-time session state** display
- **Session info** including request ID and timing

### **Test Scenarios**
1. **Start peek flow** → Verify session starts
2. **Receive peek while in session** → Verify blocked
3. **Complete flow** → Verify session ends
4. **Stale session cleanup** → Verify automatic reset

## 🚀 Benefits

### **User Experience**
- **No conflicting notifications** during active peeks
- **Consistent flow** without interruptions
- **Clear session boundaries** and state management

### **System Reliability**
- **Prevents duplicate requests** and UI conflicts
- **Automatic cleanup** of stuck sessions
- **Server-side validation** for notifications

### **Developer Experience**
- **Centralized session management** with clear APIs
- **Real-time state tracking** for debugging
- **Automatic persistence** and synchronization

## 🔍 Monitoring

### **Logs to Watch**
```
🔒 [SessionManager] Session started: waiting_response for request: abc123
🔒 [PeekDialogManager] User is in active session, blocking new peek request
🔒 [SessionManager] Session state updated to photo_capture
🔒 [SessionManager] Session ended successfully
```

### **Firestore Queries**
```javascript
// Check active sessions
db.collection('users').where('activePeekSession.isActive', '==', true)

// Check session age
db.collection('users').where('activePeekSession.startTime', '<', timestamp)
```

## 🚨 Troubleshooting

### **Common Issues**

#### **Session Not Starting**
- Check `SessionManager.initialize()` is called
- Verify Firestore permissions for `activePeekSession`
- Check console logs for initialization errors

#### **Session Not Ending**
- Verify `endSession()` is called in all exit paths
- Check for exceptions in session cleanup
- Verify Firestore update permissions

#### **Notifications Still Coming**
- Check Cloud Functions deployment
- Verify `activePeekSession` field in Firestore
- Check function logs for session checking

### **Debug Commands**
```dart
// Get current session info
final sessionInfo = sessionManager.getSessionInfo();
debugPrint('Session: $sessionInfo');

// Force session cleanup
await sessionManager.clearAllData();
```

## 🔮 Future Enhancements

### **Planned Features**
- **Session analytics** and metrics
- **Advanced session types** (group peeks, etc.)
- **Session recovery** for app crashes
- **Cross-device session sync**

### **Performance Optimizations**
- **Batch Firestore updates** for session changes
- **Caching layer** for session state
- **Background session monitoring**

---

## 📋 Implementation Checklist

- [x] **SessionManager** class with state management
- [x] **Riverpod providers** for reactive state
- [x] **Firestore integration** for server-side checking
- [x] **Cloud Functions** notification suppression
- [x] **UI integration** across all peek flow screens
- [x] **Automatic cleanup** and validation
- [x] **Debug tools** and monitoring
- [x] **Documentation** and testing guide

**Status: ✅ COMPLETE - Production Ready**
