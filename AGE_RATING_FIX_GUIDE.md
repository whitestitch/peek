# Age Rating Fix Guide - Apple Review Issue 2.3.6

## Issue Summary

**Apple Reviewer Feedback:**
> "The content description selected for the app's Age Rating indicates that the app includes In-App Controls, and we were unable to find either Parental Controls or Age Assurance mechanisms in the app."

## Root Cause

This is a **metadata configuration issue** in App Store Connect, NOT a code issue. The app's Age Rating questionnaire was configured to indicate "In-App Controls" which requires either:
- Parental Control mechanisms, OR
- Age Assurance/verification systems

Since Peekio does not have these features (and doesn't need them), we need to update the Age Rating configuration.

## Solution: Update Age Rating in App Store Connect

### Step 1: Access Age Rating Configuration

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** → **Peekio**
3. Go to **App Information** section
4. Click **Edit** next to **Age Rating**

### Step 2: Review Age Rating Questionnaire

Go through the Age Rating questionnaire and ensure the following settings:

#### Content Ratings - Answer "NO" to These Questions:

**Unrestricted Web Access:**
- ❌ NO - App does not have unrestricted web access

**In-App Purchases:**
- ✅ YES - App has in-app purchases (Premium subscription)

**User Generated Content:**
- ✅ YES - Users can share photos with each other
- Note: We have moderation via Google Cloud Vision API

**Location Services:**
- ✅ YES (Optional) - App can access location but it's optional

**Violence:**
- ❌ NO - No realistic violence, sexual violence, or cartoon violence

**Profanity or Crude Humor:**
- ❌ NO - App doesn't contain profanity

**Mature/Suggestive Themes:**
- ❌ NO - App doesn't contain mature or suggestive themes

**Horror/Fear Themes:**
- ❌ NO - App doesn't contain horror themes

**Medical/Treatment Information:**
- ❌ NO - App doesn't provide medical info

**Alcohol, Tobacco, or Drug Use:**
- ❌ NO - App doesn't contain drug references

**Gambling:**
- ❌ NO - App doesn't include gambling

**Sexual Content or Nudity:**
- ❌ NO - App doesn't contain sexual content
- Note: We have moderation to prevent inappropriate content

**Contests, Sweepstakes, Lotteries, Raffles:**
- ❌ NO - App doesn't include contests

#### CRITICAL: In-App Controls Question

**Does your app include parental controls or age assurance mechanisms?**
- ❌ **ANSWER NO** - This is the key issue
- Peekio does not have parental controls or age verification
- All users are treated equally regardless of age

### Step 3: Expected Age Rating Result

After correctly answering the questionnaire:
- **Expected Rating:** 12+ or 17+ (due to user-generated content)
- **No "Parental Controls" requirement**

### Step 4: Save and Submit

1. Review your answers carefully
2. Click **Done** to save the Age Rating
3. The age rating will be updated for your next submission

## Why This Fix is Correct

1. **No Parental Controls Needed:** Peekio is a social app where all users have the same experience. There are no age-specific restrictions or content filtering based on user age.

2. **Content Moderation Instead:** We use:
   - Google Cloud Vision API for automatic content moderation
   - Community reporting features
   - Account restriction system for violations

   This is **content moderation**, not **parental controls**.

3. **Age Rating vs Parental Controls:**
   - **Age Rating** (what we have): App is suitable for users 12+/17+
   - **Parental Controls** (what we don't have): Parents can restrict what their child sees/does in the app

   We only need the Age Rating, not Parental Controls.

## Verification Checklist

Before resubmitting to Apple:

- [ ] Age Rating questionnaire completed correctly
- [ ] "In-App Controls" question answered NO
- [ ] User Generated Content marked YES (with moderation note)
- [ ] Expected age rating is 12+ or 17+
- [ ] Age rating saved in App Store Connect
- [ ] New build submitted with updated metadata

## Additional Notes for Apple Reviewers

If Apple asks for clarification, respond with:

> "Thank you for the feedback. We have updated our Age Rating metadata in App Store Connect.
>
> Peekio does not include parental controls or age assurance mechanisms. All users have the same app experience regardless of age. We have automatic content moderation via Google Cloud Vision API and community reporting to ensure appropriate content, but this is content moderation, not parental controls.
>
> The Age Rating questionnaire has been updated to accurately reflect that the app does not have 'In-App Controls' features."

## References

- [App Store Review Guidelines 2.3.6](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
- [Age Ratings Documentation](https://developer.apple.com/help/app-store-connect/manage-app-information/choose-an-age-rating-for-your-app)

---

**Last Updated:** November 9, 2025
**Issue:** Guideline 2.3.6 - Performance - Accurate Metadata

