# App Store Connect Configuration Fixes

## Guideline 2.3.6 - Performance: Accurate Metadata

**Issue**: Age Rating indicates "In-App Controls" but app doesn't have Parental Controls or Age Assurance.

**Type**: Metadata configuration issue (NOT a code issue)

---

## Fix Instructions:

### 1. Access Age Rating Settings

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select **Peek** app
3. Click **"App Information"** in left sidebar
4. Scroll to **"Age Rating"** section
5. Click **"Edit"**

### 2. Update Age Rating Responses

Find and update these questions:

| Question | Current (Incorrect) | Correct Answer |
|----------|---------------------|----------------|
| Does your app include Parental Controls? | Yes | **No** |
| Does your app include Age Assurance mechanisms? | Yes | **No** |
| Does your app have In-App Controls? | Yes | **No** |

### 3. Confirm App Features

✅ **Peek DOES have:**
- Content reporting system
- User blocking
- Content moderation (via reports)

❌ **Peek DOES NOT have:**
- Parental controls
- Age verification systems
- Content filtering for minors
- Supervised modes
- Time limits or screen time controls

### 4. Save and Submit

1. Click **"Save"**
2. **No new build required**
3. Submit metadata update for review
4. Reply to Apple's message confirming the fix

---

## Sample Reply to Apple:

```
Thank you for bringing this to our attention.

We have reviewed and updated the Age Rating selections in App Store Connect
to accurately reflect that our app does not include Parental Controls or
Age Assurance mechanisms.

Specifically, we have set:
- "Age Assurance" to "None"
- "In-App Controls" to "None"

While our app does include a content reporting and moderation system to
maintain community safety, these are not parental control or age assurance
features.

The corrected age rating metadata has been submitted. Please let us know
if you need any additional information.
```

---

## Age Rating Recommendations:

Based on Peek's features:

### Content Description:
- **Photo Sharing**: Yes
- **Social Networking**: Yes
- **User-Generated Content**: Yes
- **Anonymous Communication**: Yes
- **Contest/Competitions**: No
- **Gambling**: No
- **In-App Controls**: **No** ❌ (This was the issue)

### Suggested Apple Global Age Rating: **12+**

Reasoning:
- Anonymous photo sharing with strangers
- User-generated content (could include mature themes)
- No explicit controls for content filtering
- Includes reporting/moderation system

---

## Verification Checklist:

Before resubmitting, verify:

- [ ] Age Rating questionnaire completed accurately
- [ ] "In-App Controls" set to "No"
- [ ] "Age Assurance" set to "None"
- [ ] All other age rating questions match app features
- [ ] App description doesn't mention parental controls
- [ ] Screenshots don't show parental control features
- [ ] Privacy policy doesn't claim age verification

---

## References:

- [Age Ratings Values and Definitions](https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions#age-rating-values)
- [Guideline 2.3.6 - Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)

