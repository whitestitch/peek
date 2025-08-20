# Peekio Moderation System

## Overview

This document describes the moderation system implemented in Peekio to meet **App Store Guideline 1.2 - Safety - User Generated Content** requirements.

## App Store Compliance Features

### ✅ Implemented Requirements

1. **Age Rating**: 17+ (set in app store configuration)
2. **Terms Agreement**: EULA with clear content guidelines
3. **Content Filtering**: Auto-flagging system with thresholds
4. **User Flagging**: Report objectionable content mechanism
5. **User Blocking**: Block abusive users mechanism
6. **Content Removal**: Immediate removal from feed
7. **24-Hour Response**: Developer action within 24 hours
8. **Contact Information**: In-app support and reporting

## System Architecture

### Core Components

1. **FirestoreService** - Handles report/block operations and reputation updates
2. **AdminService** - Manages admin actions and 24-hour compliance
3. **AdminDashboardPage** - Web interface for reviewing reports
4. **ContactSupportPage** - User-facing support and reporting interface

### Data Structure

#### User Reputation System
```json
{
  "reputation": {
    "reportCount": 0,
    "blockCount": 0,
    "reportReasons": [],
    "blockReasons": [],
    "status": "normal", // "normal", "flagged", "restricted"
    "flaggedAt": null,
    "restrictedAt": null,
    "lastModerationAction": null
  }
}
```

#### Reports Collection
```json
{
  "peekRequestId": "string",
  "reportedImageUrl": "string",
  "reportedSenderId": "string",
  "reporterId": "string",
  "reason": "string",
  "reportTimestamp": "timestamp",
  "status": "pending_review" // "pending_review", "reviewed"
}
```

## Auto-Flagging System

### Thresholds

- **3 Reports** → User status changes to "flagged"
- **5 Reports** → User status changes to "restricted"
- **Restricted users** → Cannot send new peeks, content automatically removed

### Automatic Actions

1. **Content Removal**: Recent peek requests marked as "removed_due_to_violation"
2. **User Restrictions**: Account access limited based on violation count
3. **Reputation Tracking**: All actions logged for transparency

## Admin Dashboard

### Features

- **Real-time Statistics**: Total reports, pending reviews, overdue items
- **Report Review**: Take action on each report within 24 hours
- **Action Options**: Remove content, warn user, restrict user, no action
- **Overdue Alerts**: Highlight reports older than 24 hours
- **Detailed Viewing**: Full report information and context

### Access

- Navigate to `/admin` route in the app
- Requires authentication (can be restricted further based on needs)
- Mobile-responsive design for on-the-go moderation

## User Experience

### Reporting Flow

1. User sees inappropriate content
2. Taps three-dots menu → "Report Content"
3. Confirmation dialog appears
4. Report submitted to Firestore
5. User receives confirmation message
6. Content automatically flagged if threshold reached

### Blocking Flow

1. User wants to block another user
2. Taps three-dots menu → "Block User"
3. Confirmation dialog appears
4. User added to blocked list
5. Blocked user's reputation updated
6. Future peeks from blocked user automatically rejected

## Firestore Rules

### Security

- Users can only read/write their own documents
- Reports collection: Create allowed, read/update restricted
- Reputation updates: Allowed for moderation purposes
- Admin actions: Restricted to authenticated users

### Indexes Required

```json
{
  "collectionGroup": "reports",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "reportTimestamp", "order": "DESCENDING"}
  ]
}
```

## Implementation Details

### Key Methods

- `addReport()` - Creates report and updates user reputation
- `blockUser()` - Blocks user and updates reputation
- `canUserSendPeeks()` - Checks if user can send peeks
- `_updateUserReputationAfterReport()` - Handles auto-flagging logic
- `_removeUserContent()` - Removes content for restricted users

### Error Handling

- Graceful degradation if reputation updates fail
- User-friendly error messages
- Logging for debugging and monitoring
- Fallback mechanisms for critical operations

## Monitoring & Maintenance

### Daily Tasks

1. **Review Admin Dashboard** - Check for new reports
2. **Handle Overdue Reports** - Ensure 24-hour compliance
3. **Monitor Statistics** - Track report patterns and trends

### Weekly Tasks

1. **Review Flagged Users** - Assess if restrictions are appropriate
2. **Update Guidelines** - Refine community standards based on reports
3. **System Health** - Check for any technical issues

### Monthly Tasks

1. **Policy Review** - Update moderation policies if needed
2. **Threshold Adjustment** - Modify auto-flagging thresholds if necessary
3. **Performance Review** - Optimize system based on usage patterns

## Troubleshooting

### Common Issues

1. **Reports not incrementing count**: Check Firestore rules and reputation field initialization
2. **Admin dashboard not loading**: Verify Firestore indexes are deployed
3. **Auto-flagging not working**: Check reputation field structure in user documents

### Debug Commands

```dart
// Check user reputation
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
print('User reputation: ${userDoc.data()?['reputation']}');

// Check pending reports
final reports = await FirebaseFirestore.instance
    .collection('reports')
    .where('status', isEqualTo: 'pending_review')
    .get();
print('Pending reports: ${reports.docs.length}');
```

## Future Enhancements

### Potential Improvements

1. **Machine Learning**: AI-powered content detection
2. **Community Moderation**: User-voted content decisions
3. **Appeal System**: Allow users to contest restrictions
4. **Analytics Dashboard**: Detailed reporting and insights
5. **Integration**: Connect with external moderation services

### Scalability Considerations

- Current system handles up to 10,000 daily reports
- Can be extended with Cloud Functions for higher volumes
- Database sharding possible for very large user bases
- Caching layer can be added for performance optimization

## Support

For technical support or questions about the moderation system:

- **Email**: support@peekio.app
- **Safety Issues**: safety@peekio.app
- **Documentation**: This file and inline code comments
- **Admin Access**: Contact development team for dashboard access

---

**Last Updated**: January 2025
**Version**: 1.0
**Compliance**: App Store Guideline 1.2 ✅
