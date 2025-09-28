// Demo Account Setup Script for Apple App Store Review
// Run this script to create and populate the demo account with sample data

const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

// Initialize Firebase Admin SDK
const serviceAccount = require('../secrets/service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'your-project-id.appspot.com' // Replace with your actual bucket
});

const auth = getAuth();
const db = getFirestore();

const DEMO_EMAIL = 'peekio.demo@example.com';
const DEMO_PASSWORD = 'PeekDemo2025!';
const DEMO_DISPLAY_NAME = 'Demo User';

async function setupDemoAccount() {
  console.log('🎭 Setting up demo account for Apple App Store review...');

  try {
    // 1. Create or update demo user in Firebase Auth
    let demoUser;
    try {
      demoUser = await auth.getUserByEmail(DEMO_EMAIL);
      console.log('✅ Demo user already exists, updating...');

      // Update existing user
      await auth.updateUser(demoUser.uid, {
        password: DEMO_PASSWORD,
        displayName: DEMO_DISPLAY_NAME,
        emailVerified: true,
      });
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log('📝 Creating new demo user...');
        demoUser = await auth.createUser({
          email: DEMO_EMAIL,
          password: DEMO_PASSWORD,
          displayName: DEMO_DISPLAY_NAME,
          emailVerified: true,
        });
      } else {
        throw error;
      }
    }

    const demoUid = demoUser.uid;
    console.log(`✅ Demo user UID: ${demoUid}`);

    // 2. Create user profile in Firestore
    await db.collection('users').doc(demoUid).set({
      email: DEMO_EMAIL,
      displayName: DEMO_DISPLAY_NAME,
      createdAt: FieldValue.serverTimestamp(),
      isPremium: true, // Grant premium for full feature access
      premiumPlanId: 'peek.premium.monthly',
      premiumGrantedAt: FieldValue.serverTimestamp(),

      // Statistics for demo purposes
      likesReceivedCount: 15,
      dislikesReceivedCount: 3,
      peeksSentCount: 22,
      peeksReceivedCount: 18,

      // Reputation system
      reputation: {
        status: 'normal',
        reportCount: 0,
        blockCount: 0,
        reportReasons: [],
        blockReasons: [],
        lastModerationAction: null,
      },

      // Demo-specific flags
      isDemoAccount: true,
      demoAccountCreatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    // 3. Create sample peek requests (sent by demo user)
    const samplePeekRequests = [
      {
        status: 'completed',
        createdAt: Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)), // 2 days ago
        completedAt: Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000 + 5 * 60 * 1000)),
        reaction: 'like',
        reactionAt: Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000 + 10 * 60 * 1000)),
      },
      {
        status: 'completed',
        createdAt: Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)), // 1 day ago
        completedAt: Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000 + 3 * 60 * 1000)),
        reaction: 'dislike',
        reactionAt: Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000 + 8 * 60 * 1000)),
      },
      {
        status: 'completed',
        createdAt: Timestamp.fromDate(new Date(Date.now() - 12 * 60 * 60 * 1000)), // 12 hours ago
        completedAt: Timestamp.fromDate(new Date(Date.now() - 12 * 60 * 60 * 1000 + 7 * 60 * 1000)),
        reaction: 'like',
        reactionAt: Timestamp.fromDate(new Date(Date.now() - 12 * 60 * 60 * 1000 + 15 * 60 * 1000)),
      },
    ];

    console.log('📸 Creating sample peek requests...');
    for (let i = 0; i < samplePeekRequests.length; i++) {
      const peekData = {
        senderUid: demoUid,
        receiverUid: 'sample_receiver_' + (i + 1), // Placeholder receiver
        ...samplePeekRequests[i],
        isDemoData: true,
      };

      await db.collection('peek_requests').add(peekData);
    }

    // 4. Create sample received reactions
    console.log('❤️ Creating sample received reactions...');
    const sampleReactions = [
      { reactionType: 'like', timestamp: Timestamp.fromDate(new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)) },
      { reactionType: 'like', timestamp: Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)) },
      { reactionType: 'dislike', timestamp: Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)) },
    ];

    for (let i = 0; i < sampleReactions.length; i++) {
      await db.collection('users').doc(demoUid)
        .collection('received_reactions')
        .add({
          ...sampleReactions[i],
          fromUid: 'sample_sender_' + (i + 1),
          peekRequestId: 'sample_request_' + (i + 1),
          isDemoData: true,
        });
    }

    // 5. Create sample content moderation scenarios
    console.log('🛡️ Setting up moderation examples...');

    // Sample report (for admin dashboard demo)
    await db.collection('reports').add({
      peekRequestId: 'sample_reported_content',
      reportedSenderId: 'sample_reported_user',
      reporterId: demoUid,
      reason: 'inappropriate_content',
      reportTimestamp: Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000)), // 2 hours ago
      status: 'pending_review',
      isDemoData: true,
    });

    // Sample blocked user
    await db.collection('users').doc(demoUid).update({
      blockedSenderIds: ['sample_blocked_user_1'],
    });

    console.log('✅ Demo account setup completed successfully!');
    console.log('\n📋 Demo Account Details:');
    console.log(`Email: ${DEMO_EMAIL}`);
    console.log(`Password: ${DEMO_PASSWORD}`);
    console.log(`UID: ${demoUid}`);
    console.log('\n🎯 Features demonstrated:');
    console.log('- ✅ Premium subscription active');
    console.log('- ✅ Sample peek history (sent/received)');
    console.log('- ✅ Reaction statistics');
    console.log('- ✅ Content moderation examples');
    console.log('- ✅ User blocking functionality');
    console.log('- ✅ All safety features accessible');

  } catch (error) {
    console.error('❌ Error setting up demo account:', error);
    process.exit(1);
  }
}

// Run the setup
setupDemoAccount().then(() => {
  console.log('\n🎉 Demo account ready for Apple App Store review!');
  process.exit(0);
});
