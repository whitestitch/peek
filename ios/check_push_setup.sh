#!/bin/bash
echo "🔍 Checking Push Notification Setup..."
echo ""

# Check entitlements
echo "📄 Checking entitlements files:"
if [ -f "ios/Runner/Runner-Debug.entitlements" ]; then
    echo "✅ Runner-Debug.entitlements exists"
    grep -A1 "aps-environment" ios/Runner/Runner-Debug.entitlements
else
    echo "❌ Runner-Debug.entitlements missing"
fi

if [ -f "ios/Runner/Runner-Release.entitlements" ]; then
    echo "✅ Runner-Release.entitlements exists"
    grep -A1 "aps-environment" ios/Runner/Runner-Release.entitlements
else
    echo "❌ Runner-Release.entitlements missing"
fi
echo ""

# Check Info.plist for background modes
echo "📱 Checking Info.plist background modes:"
grep -A2 "UIBackgroundModes" ios/Runner/Info.plist
echo ""

# Check if Push Notifications capability is in project
echo "🔔 Push Notification capability check:"
if grep -q "com.apple.Push" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null; then
    echo "✅ Push Notifications capability found"
else
    echo "⚠️  Push Notifications capability not found - add it in Xcode!"
fi
echo ""

# Check Firebase config
echo "🔥 Checking Firebase configuration:"
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "✅ GoogleService-Info.plist exists"
    grep "GCM_SENDER_ID" ios/Runner/GoogleService-Info.plist
else
    echo "❌ GoogleService-Info.plist missing!"
fi
echo ""

echo "✅ Diagnostic complete!"
