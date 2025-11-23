# Apple Review - Quick Action Checklist

## 🚨 CRITICAL: Do This FIRST Before Any New Submission

### 1. Fix Age Rating in App Store Connect (5 minutes)

**This MUST be done before submitting a new build, otherwise the same rejection will occur.**

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to: **My Apps** → **Peekio** → **App Information**
3. Click **Edit** next to **Age Rating**
4. Find the question: **"Does your app include parental controls or age assurance mechanisms?"**
5. Change answer to: **NO** ❌
6. Click **Done** and save

**See full guide:** `AGE_RATING_FIX_GUIDE.md`

---

## ✅ Code Fixes Already Implemented

### Network Timeout Fixes (Already Done)
- ✅ Increased Cloud Function timeout: 30s → 90s
- ✅ Added automatic retry logic (3 attempts)
- ✅ Added image upload timeout protection
- ✅ Exponential backoff between retries
- ✅ Better error messages for users

**Files Modified:**
- `lib/features/peek/controllers/peek_controller.dart`
- `lib/features/peek/camera/photo_capture_logic.dart`

---

## 📋 Pre-Submission Checklist

### Required Before Submission:
- [ ] **Update Age Rating in App Store Connect** (see step 1 above)
- [ ] Update version number in `pubspec.yaml` (e.g., 1.0.1+7)
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Build and test on physical device
- [ ] Upload new build to App Store Connect
- [ ] Submit for review with response to Apple

### Optional Testing (Recommended):
- [ ] Test with Network Link Conditioner (slow network)
- [ ] Test complete Peek flow on two devices
- [ ] Verify error messages are user-friendly
- [ ] Test with TestFlight before submission

---

## 📝 Response to Apple Review Board

When submitting, include this message in the "Review Notes" or response to reviewer:

```
Thank you for the detailed feedback and documentation references.

Guideline 2.3.6 (Age Rating):
We have corrected the Age Rating metadata in App Store Connect. The app does not
include "In-App Controls" or parental control features. All users have the same app
experience. We use automatic content moderation via Google Cloud Vision API for
safety, but this is content moderation, not parental controls.

Guideline 2.1 (Timeout Issues):
We have implemented comprehensive fixes to address network timeout issues:

1. Increased Timeouts: All network operations now have 90-second timeouts (increased
   from 30 seconds) to accommodate slower network conditions.

2. Automatic Retry Logic: Implemented retry mechanisms (3 attempts with exponential
   backoff) for all critical network operations including:
   - Peek request initiation (Cloud Function calls)
   - Image upload to Firebase Storage
   - Network URL retrieval

3. Better Error Handling: Improved error messages for users with clear, actionable
   feedback instead of technical errors.

4. Network Resilience: Following Apple's guidelines from 'Designing for Real-World
   Networks', we've added:
   - Graceful degradation on network failures
   - Exponential backoff between retries
   - Specific error handling for timeout and availability issues

These changes ensure the app works reliably even under poor network conditions such
as those that might occur during on-device review testing.

The app requires two devices for testing the Peek feature. Demo accounts have been
provided in the review notes.
```

---

## 🎯 Summary

**What was wrong:**
1. Age Rating metadata incorrectly set in App Store Connect
2. Network timeouts too short (30s) with no retry logic

**What we fixed:**
1. Created guide to fix Age Rating (you must do this manually)
2. Increased timeouts to 90 seconds
3. Added automatic retry logic (3 attempts)
4. Better error handling and messages

**What you need to do:**
1. Fix Age Rating in App Store Connect (5 minutes)
2. Update version and build new release
3. Submit with response message above

---

## 📚 Detailed Documentation

- **Comprehensive Fix Summary:** `APPLE_REVIEW_RESPONSE.md`
- **Age Rating Guide:** `AGE_RATING_FIX_GUIDE.md`
- **This Quick Guide:** `APPLE_REVIEW_QUICK_ACTION.md`

---

**Created:** November 9, 2025
**Status:** ✅ Code fixes complete, ⚠️ Metadata fix required

