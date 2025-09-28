# App Store Connect Configuration Guide
## Complete Setup for Apple App Store Review Approval

### 🚀 **Step 1: In-App Purchase Products Setup**

#### 1.1 Create Premium Subscription Product
1. **Go to:** App Store Connect → Your App → Features → In-App Purchases
2. **Click:** "+" to create new product
3. **Product Details:**
   - **Type:** Auto-Renewable Subscription
   - **Reference Name:** Peekio Premium Monthly
   - **Product ID:** `peek.premium.monthly`
   - **Subscription Group:** Create new "Premium Features"

#### 1.2 Configure Subscription Details
- **Subscription Duration:** 1 Month
- **Price:** $4.99 (Tier 5)
- **Localizations:**
  - **Display Name:** Peekio Premium
  - **Description:** "Unlock unlimited peek requests, priority matching, and advanced statistics. Experience Peekio without limits!"

#### 1.3 App Review Information for IAP
- **Screenshot:** Upload `premium_subscription_page.png`
- **Review Notes:** "Use demo account peekio.demo@example.com (password: PeekDemo2025!) to test premium features. Subscription is pre-activated for full feature access."

#### 1.4 Submit IAP for Review
1. **Status:** Change to "Ready for Review"
2. **Submit:** Click "Submit for Review"
3. ⚠️ **Important:** IAP must be approved before app binary can be reviewed

---

### 🛡️ **Step 2: App Review Information**

#### 2.1 Demo Account Setup
**Go to:** App Store Connect → Your App → App Information → App Review Information

**Demo Account Details:**
```
Username: peekio.demo@example.com
Password: PeekDemo2025!
```

**Additional Information:**
```
This demo account includes:
✅ Active premium subscription
✅ Pre-populated peek history (sent/received)
✅ Sample reactions and statistics
✅ Content moderation examples
✅ All safety features accessible

The account demonstrates full app functionality including:
- Anonymous photo sharing
- Real-time matching system
- Premium features (unlimited usage)
- Content reporting and blocking
- User safety measures
```

#### 2.2 Contact Information
```
First Name: Peekio
Last Name: Support Team
Phone Number: +1-555-PEEKIO
Email Address: support@peekio.app
```

---

### 📱 **Step 3: App Information Updates**

#### 3.1 Age Rating
- **Go to:** App Information → Age Rating
- **Set to:** 17+ (Mature/Restricted)
- **Reasons:**
  - Infrequent/Mild Sexual Content or Nudity
  - User Generated Content

#### 3.2 Content Rights
- **Third Party Content:** No
- **Uses Advertising Identifier:** No (unless you have ads)

---

### 🔒 **Step 4: Privacy & Safety Compliance**

#### 4.1 Privacy Policy
- **URL:** https://your-domain.com/privacy-policy.html
- **Ensure it covers:**
  - Anonymous photo sharing
  - Data collection and usage
  - User safety measures
  - Content moderation policies

#### 4.2 App Privacy Details
**Data Collection Categories:**
- **Photos:** Used for core app functionality
- **User ID:** For account management
- **Usage Data:** For analytics and improvements
- **Diagnostics:** For app performance

---

### 📸 **Step 5: Screenshots for IAP Review**

#### Required Screenshots (1290 x 2796 px):
1. **`premium_subscription_page.png`**
   - Shows premium features and pricing
   - Clear "Subscribe" button visible
   - Features list clearly readable

2. **`iap_purchase_dialog.png`**
   - iOS native purchase confirmation
   - Price and product name visible
   - "Cancel" and "Buy" buttons shown

3. **`premium_features_active.png`**
   - App showing premium features unlocked
   - Premium badge/indicator visible
   - Advanced features accessible

4. **`subscription_settings.png`**
   - Settings page with subscription management
   - "Manage Subscription" button visible
   - Current subscription status shown

---

### ⚡ **Step 6: Binary Submission**

#### 6.1 Before Upload
1. ✅ All IAP products submitted and approved
2. ✅ Demo account created and tested
3. ✅ Screenshots uploaded
4. ✅ App review information complete

#### 6.2 Upload New Binary
1. **Build:** Create release build with latest changes
2. **Upload:** Use Xcode or Application Loader
3. **Select:** Choose uploaded build in App Store Connect
4. **Submit:** Click "Submit for Review"

---

### 🔧 **Step 7: Review Response Template**

**If you need to respond to Apple:**

```
Dear App Store Review Team,

Thank you for your feedback. We have addressed all the issues mentioned:

GUIDELINE 2.1 - IAP PRODUCTS:
✅ All in-app purchase products have been submitted for review
✅ Required screenshots and metadata provided
✅ Demo account with active subscription available

GUIDELINE 1.2 - USER SAFETY:
✅ Content filtering system implemented (Google Cloud Vision)
✅ User reporting mechanism for objectionable content
✅ User blocking functionality available
✅ Immediate content removal from feed
✅ Developer response within 24 hours guaranteed
✅ Admin dashboard for content moderation

DEMO ACCOUNT ACCESS:
✅ Username: peekio.demo@example.com
✅ Password: PeekDemo2025!
✅ Pre-populated with sample content and active premium subscription

All features are fully functional and demonstrate complete app capabilities.

Best regards,
Peekio Development Team
```

---

### ✅ **Step 8: Final Checklist**

Before submitting:
- [ ] IAP products created and submitted
- [ ] Demo account created and verified
- [ ] Screenshots uploaded for IAP review
- [ ] App review information complete
- [ ] Age rating set to 17+
- [ ] Privacy policy updated and accessible
- [ ] Content moderation system active
- [ ] 24-hour response monitoring enabled
- [ ] New binary uploaded with all fixes
- [ ] All safety features tested and working

---

### 🎯 **Expected Timeline**
- **IAP Review:** 24-48 hours
- **App Binary Review:** 24-48 hours after IAP approval
- **Total:** 2-4 days for complete approval

### 📞 **Support Contact**
If Apple needs clarification:
- **Email:** support@peekio.app
- **Response Time:** Within 24 hours
- **Admin Dashboard:** Available for immediate content review
