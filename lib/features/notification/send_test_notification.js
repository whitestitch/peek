/**
 * Script to send a test push notification via Firebase Cloud Messaging (FCM)
 * for testing notification taps and navigation in the Peek app.
 *
 * This version explicitly loads the service account key from a fixed,
 * gitignored path relative to the project root.
 */

const admin = require('firebase-admin');
const path = require('path'); // Import the 'path' module

// --- Configuration ---

// 1. Path to your Firebase Admin SDK JSON file.
//    *** Assumes the key file is located at PROJECT_ROOT/secrets/service-account.json ***
//    Calculates the path relative to this script's location.
const SERVICE_ACCOUNT_RELATIVE_PATH = '../../../secrets/service-account.json'; // Path from lib/features/notification/ up to root and down to secrets/
const SERVICE_ACCOUNT_ABSOLUTE_PATH = path.resolve(__dirname, SERVICE_ACCOUNT_RELATIVE_PATH);

// 2. Target device FCM token.
const TARGET_FCM_TOKEN = 'e5ALokKnm0NQlspd51-Lh4:APA91bF3p-BHSfQe6EIwLuaw5WQ878v0_J6QKKwnqio147M5oFRKJh_sWQ26wvApJ0SEiJ-JWQ_oHdG7MIwSoHlc6E6NpX7D_J-hFsOoOVqoid5oLO0AvE8';

// 3. Data Payload values
const TEST_REQUEST_ID = 'test-script-req-003'; // Example Request ID
const TEST_IMAGE_URL = 'https://picsum.photos/seed/peektest3/400/600'; // Example Image URL

// 4. APNS Topic (iOS Bundle ID)
const APNS_TOPIC = 'com.fab.peek'; // <-- *** REPLACE THIS *** e.g., 'com.yourcompany.peek'

// --- End Configuration ---


/**
 * Initializes Firebase Admin SDK by explicitly loading the cert
 * from the calculated absolute path.
 */
function initializeFirebaseAdmin()
{
  console.log(`🔑 Attempting to initialize Firebase Admin SDK using service account file at: ${SERVICE_ACCOUNT_ABSOLUTE_PATH}`);

  try
  {
    // Explicitly require the file using the calculated absolute path
    const serviceAccount = require(SERVICE_ACCOUNT_ABSOLUTE_PATH);

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('✅ Firebase Admin SDK initialized successfully by explicitly loading cert from fixed relative path.');

  } catch (error)
  {
    console.error('❌ Failed to initialize Firebase Admin SDK using fixed relative path:');
    console.error(`   Calculated Path: ${SERVICE_ACCOUNT_ABSOLUTE_PATH}`);
    console.error('   Relative Path Used: ' + SERVICE_ACCOUNT_RELATIVE_PATH);
    console.error('   Script Directory (__dirname): ' + __dirname);
    console.error('   Ensure the key file exists at PROJECT_ROOT/secrets/service-account.json');
    console.error('   Also check file permissions and JSON validity.');
    console.error('   Error details:', error.message);
    if (error.code)
    {
      console.error(`   Error Code: ${error.code}`); // e.g., MODULE_NOT_FOUND if path is wrong
    }
    process.exit(1); // Exit if initialization fails
  }
}

/**
 * Constructs the FCM message payload.
 * @returns {object} The FCM message object.
 */
function constructMessagePayload()
{
  if (!TARGET_FCM_TOKEN || TARGET_FCM_TOKEN.includes('YOUR_DEVICE_FCM_TOKEN_HERE') || TARGET_FCM_TOKEN === 'e5ALokKnm0NQlsp...')
  { // Added check for the example token
    console.error('❌ Error: TARGET_FCM_TOKEN is not set or is still the placeholder/example value.');
    console.error('   Please replace it with a valid FCM token from your device.');
    process.exit(1);
  }
  if (!APNS_TOPIC || APNS_TOPIC === 'YOUR_IOS_BUNDLE_ID')
  {
    console.warn('⚠️ Warning: APNS topic is not set or is still the placeholder.');
    console.warn('   Replace this with your actual iOS Bundle ID for APNS notifications to work correctly on iOS.');
    // Allow continuing but warn user.
  }


  const message = {
    notification: {
      title: 'PEEK: Test Notification 🔑', // Changed emoji again
      body: `Tap for request: ${TEST_REQUEST_ID}`,
    },
    token: TARGET_FCM_TOKEN,
    data: {
      'requestId': TEST_REQUEST_ID,
      'imageUrl': TEST_IMAGE_URL,
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'source': 'test-script-fixed-path'
    },
    apns: {
      payload: { aps: { 'sound': 'default', 'badge': 1 } },
      headers: { 'apns-priority': '10', 'apns-topic': APNS_TOPIC }
    },
    android: {
      priority: 'high',
      notification: { 'sound': 'default' },
    },
  };
  return message;
}


/**
 * Sends the constructed message using Firebase Admin SDK.
 */
async function sendTestNotification()
{
  initializeFirebaseAdmin(); // Uses explicit relative path loading now
  const messagePayload = constructMessagePayload();

  console.log('\n--- Sending Test Message (Fixed Path Method) ---');
  console.log('To Token:', messagePayload.token.substring(0, 15) + '...');
  console.log('Data Payload:', messagePayload.data);
  console.log('APNS Topic:', messagePayload.apns.headers['apns-topic']);
  console.log('--------------------------------------------\n');

  try
  {
    const response = await admin.messaging().send(messagePayload);
    console.log('✅ Successfully sent message:', response);
  } catch (error)
  {
    console.error('❌ Error sending message via FCM:');
    // ... (keep the detailed error handling from previous version) ...
    if (error.code === 'messaging/invalid-argument')
    {
      console.error('   Code: messaging/invalid-argument...');
    } else if (error.code === 'messaging/registration-token-not-registered')
    {
      console.error('   Code: messaging/registration-token-not-registered...');
      console.error(`   Error: The provided FCM token (${TARGET_FCM_TOKEN.substring(0, 15)}...) is no longer valid.`);
    } else if (error.code === 'messaging/invalid-apns-credentials' || error.code === 'messaging/mismatched-credential')
    {
      console.error(`   Code: ${error.code}`);
      console.error('   Error related to APNs credentials in Firebase Console. Check Project Settings > Cloud Messaging > Apple app configuration.');
    } else
    {
      console.error(`   Error Code: ${error.code || 'N/A'}`);
      console.error('   Error details:', error);
    }
  }
}

// --- Execute the script ---
sendTestNotification();