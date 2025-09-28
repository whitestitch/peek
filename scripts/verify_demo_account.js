// Demo Account Verification Script
// Verifies that the demo account is properly set up for Apple App Store review

const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

// Initialize Firebase Admin SDK
const serviceAccount = require('../secrets/service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = getAuth();
const db = getFirestore();

const DEMO_EMAIL = 'peekio.demo@example.com';

async function verifyDemoAccount() {
  console.log('🔍 Verifying demo account setup...\n');

  try {
    // 1. Verify user exists in Firebase Auth
    const demoUser = await auth.getUserByEmail(DEMO_EMAIL);
    console.log('✅ Auth User:', {
      uid: demoUser.uid,
      email: demoUser.email,
      displayName: demoUser.displayName,
      emailVerified: demoUser.emailVerified,
    });

    const demoUid = demoUser.uid;

    // 2. Verify user profile in Firestore
    const userDoc = await db.collection('users').doc(demoUid).get();
    if (!userDoc.exists) {
      throw new Error('User profile not found in Firestore');
    }

    const userData = userDoc.data();
    console.log('✅ User Profile:', {
      isPremium: userData.isPremium,
      likesReceived: userData.likesReceivedCount,
      dislikesReceived: userData.dislikesReceivedCount,
      peeksSent: userData.peeksSentCount,
      peeksReceived: userData.peeksReceivedCount,
      reputationStatus: userData.reputation?.status,
    });

    // 3. Verify peek requests
    const peekRequests = await db.collection('peek_requests')
      .where('senderUid', '==', demoUid)
      .get();

    console.log(`✅ Peek Requests: ${peekRequests.size} sample requests found`);

    // 4. Verify received reactions
    const reactions = await db.collection('users').doc(demoUid)
      .collection('received_reactions')
      .get();

    console.log(`✅ Received Reactions: ${reactions.size} sample reactions found`);

    // 5. Verify moderation data
    const reports = await db.collection('reports')
      .where('reporterId', '==', demoUid)
      .get();

    console.log(`✅ Reports: ${reports.size} sample reports found`);

    // 6. Check blocked users
    const blockedUsers = userData.blockedSenderIds || [];
    console.log(`✅ Blocked Users: ${blockedUsers.length} blocked users`);

    // 7. Verify premium features
    const premiumFeatures = {
      isPremium: userData.isPremium === true,
      hasValidPlan: userData.premiumPlanId === 'peek.premium.monthly',
      hasGrantDate: !!userData.premiumGrantedAt,
    };

    console.log('✅ Premium Features:', premiumFeatures);

    // Summary
    console.log('\n📊 Demo Account Summary:');
    console.log(`- User Authentication: ✅`);
    console.log(`- Premium Access: ${premiumFeatures.isPremium ? '✅' : '❌'}`);
    console.log(`- Sample Content: ${peekRequests.size > 0 ? '✅' : '❌'}`);
    console.log(`- Reaction History: ${reactions.size > 0 ? '✅' : '❌'}`);
    console.log(`- Moderation Examples: ${reports.size > 0 ? '✅' : '❌'}`);
    console.log(`- Safety Features: ${blockedUsers.length > 0 ? '✅' : '❌'}`);

    console.log('\n🎯 Ready for App Store Review!');
    console.log(`Demo Email: ${DEMO_EMAIL}`);
    console.log(`Demo Password: PeekDemo2025!`);

  } catch (error) {
    console.error('❌ Demo account verification failed:', error);
    process.exit(1);
  }
}

// Run verification
verifyDemoAccount().then(() => {
  console.log('\n✅ Demo account verification completed successfully!');
  process.exit(0);
});
