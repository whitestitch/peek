const admin = require('firebase-admin');

// Replace with the path to your Firebase Admin SDK JSON
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// 🔁 Replace this with your actual iOS device FCM token
const token = 'fHsc8NH_KEZPnkkCvaAMQo:APA91bGeol55t15-4gcZpCK1eiumwWY2KcmiRXj35PvEdAcO97Mz8xwC_fJPadH_PtO_qY930vQiqI0BdFESP2m_sn0y2kCxBcw_FaNM1_BZzA87GqKEd9s';

const message = {
  notification: {
    title: '👋 Peek Test',
    body: 'This is a test push notification!',
  },
  token,
  data: {
    route: '/receive', // Optional: auto-open route in your app
  },
};

admin.messaging().send(message)
  .then((response) =>
  {
    console.log('✅ Successfully sent message:', response);
  })
  .catch((error) =>
  {
    console.error('❌ Error sending message:', error);
  });
