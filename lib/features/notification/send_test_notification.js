/**
 * Script to send a test push notification via Firebase Cloud Messaging (FCM)
 * for testing notification taps and navigation in the Peek app.
 */

const admin = require('firebase-admin');

// --- Configuration ---

// 1. Path to your Firebase Admin SDK JSON file.
//    Download this from Firebase Project Settings > Service accounts > Generate new private key
const SERVICE_ACCOUNT_PATH = './service-account.json'; // <-- Make sure this path is correct

// 2. Target device FCM token.
//    Get this from your app's debug logs (search for 'FCM Token:').
const TARGET_FCM_TOKEN = 'e5ALokKnm0NQlspd51-Lh4:APA91bF3p-BHSfQe6EIwLuaw5WQ878v0_J6QKKwnqio147M5oFRKJh_sWQ26wvApJ0SEiJ-JWQ_oHdG7MIwSoHlc6E6NpX7D_J-hFsOoOVqoid5oLO0AvE8';

// 3. Data Payload values for testing navigation.
//    These should match what your NotificationService expects.
const TEST_REQUEST_ID = 'test-script-req-001'; // Example Request ID
const TEST_IMAGE_URL = 'https://picsum.photos/seed/peektest/400/600'; // Example Image URL (using a placeholder service)

// --- End Configuration ---


/**
 * Initializes Firebase Admin SDK.
 */
function initializeFirebaseAdmin()
{
  try
  {
    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('🔑 Firebase Admin SDK initialized successfully.');
  } catch (error)
  {
    console.error('❌ Failed to initialize Firebase Admin SDK:');
    console.error(`   Ensure '${SERVICE_ACCOUNT_PATH}' is correct and the file exists.`);
    console.error('   Error details:', error.message);
    process.exit(1); // Exit if initialization fails
  }
}

/**
 * Constructs the FCM message payload.
 * @returns {object} The FCM message object.
 */
function constructMessagePayload()
{
  // --- CORRECTED IF CONDITION ---
  // Check if the token is missing OR if it *still contains the placeholder text*
  if (!TARGET_FCM_TOKEN || TARGET_FCM_TOKEN === 'YOUR_DEVICE_FCM_TOKEN_HERE')
  {
    console.error('❌ Error: TARGET_FCM_TOKEN is not set. Please replace the placeholder value at the top of the script.');
    process.exit(1);
  }

  // --- FCM Message Structure ---
  const message = {
    // ** Notification Payload (Visible to User) **
    notification: {
      title: 'PEEK: Test Notification ✨',
      body: `Tap to view peek for request: ${TEST_REQUEST_ID}`,
    },

    // ** Target Device **
    token: TARGET_FCM_TOKEN,

    // ** Data Payload (Used by App Logic) **
    // Must contain 'requestId' and 'imageUrl' for the Peek app's tap handler.
    data: {
      'requestId': TEST_REQUEST_ID,
      'imageUrl': TEST_IMAGE_URL,
      // You can add other data fields here if needed later
      // 'source': 'test-script'
    },

    // ** Platform Specific Configurations (Optional) **

    // Apple Push Notification Service (APNs) options
    apns: {
      payload: {
        aps: {
          'sound': 'default', // Standard notification sound
          'badge': 1,         // Set the app badge number (optional)
          // 'content-available': 1 // Use for silent notifications if needed
        },
      },
      // headers: { 'apns-priority': '10' } // Optional: priority
    },

    // Android options
    android: {
      priority: 'high', // Ensure timely delivery ('normal' or 'high')
      notification: {
        'sound': 'default', // Standard notification sound
        'click_action': 'FLUTTER_NOTIFICATION_CLICK', // Standard action for Flutter taps
        // 'icon': 'stock_ticker_update', // Optional: custom icon
        // 'color': '#rrggbb',          // Optional: custom color
      },
    },
  };
  // --- End FCM Message Structure ---

  return message;
}


/**
 * Sends the constructed message using Firebase Admin SDK.
 */
async function sendTestNotification()
{
  initializeFirebaseAdmin();
  const messagePayload = constructMessagePayload();

  console.log('\n--- Sending Test Message ---');
  console.log('To Token:', messagePayload.token.substring(0, 15) + '...'); // Log prefix only
  console.log('Data Payload:', messagePayload.data);
  console.log('--------------------------\n');


  try
  {
    const response = await admin.messaging().send(messagePayload);
    console.log('✅ Successfully sent message:', response); // response is typically the messageId
  } catch (error)
  {
    console.error('❌ Error sending message via FCM:');
    if (error.code === 'messaging/invalid-argument')
    {
      console.error('   Possible issue: Invalid FCM token format or missing fields.');
    } else if (error.code === 'messaging/registration-token-not-registered')
    {
      console.error(`   Error: The provided FCM token (${TARGET_FCM_TOKEN.substring(0, 15)}...) is no longer valid or unregistered.`);
      console.error('   Ensure the token is current and from the correct device/app instance.');
    } else
    {
      console.error('   Error details:', error);
    }
  }
}

// --- Execute the script ---
sendTestNotification();