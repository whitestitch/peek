// ✅ Production-ready Cloud Functions for Peek

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { getStorage } = require("firebase-admin/storage");
const admin = require("firebase-admin");
const vision = require("@google-cloud/vision");
const logger = require("firebase-functions/logger");


admin.initializeApp();
const visionClient = new vision.ImageAnnotatorClient();


// ✅ 1. Notify receiver when a Peek is created
exports.notifyOnPeekCreated = onDocumentCreated("peek_requests/{requestId}", async (event) =>
{
  const snapshot = event.data;
  if (!snapshot) return logger.error("❌ No snapshot data");

  const data = snapshot.data();
  const imageUrl = data?.imageUrl;
  const to = data?.to;

  if (!imageUrl || !to)
  {
    return logger.warn("❗️Missing imageUrl or 'to' field.");
  }

  const payload = {
    notification: {
      title: "📸 New Peek Incoming!",
      body: "Tap to reveal your new Peek photo 👀",
    },
    data: {
      requestId: event.params.requestId,
      imageUrl,
    },
    token: to,
  };

  try
  {
    await admin.messaging().send(payload);
    logger.info(`✅ Notification sent to: ${to.slice(0, 10)}...`);
  } catch (err)
  {
    logger.error("❌ Failed to send notification:", err);
  }
});


// ✅ 2. Moderate uploaded images with Vision API
exports.moderateImageUpload = onObjectFinalized({ bucket: process.env.FIREBASE_STORAGE_BUCKET }, async (event) =>
{
  const filePath = event.name;
  const bucketName = event.bucket;
  const gcsUri = `gs://${bucketName}/${filePath}`;

  logger.info(`🔍 Moderating uploaded image: ${gcsUri}`);

  try
  {
    const [result] = await visionClient.safeSearchDetection(gcsUri);
    const detections = result.safeSearchAnnotation;

    logger.info("👁 SafeSearch results:", detections);

    const unsafe = ["LIKELY", "VERY_LIKELY"];
    if (
      unsafe.includes(detections.adult) ||
      unsafe.includes(detections.violence) ||
      unsafe.includes(detections.racy)
    )
    {
      logger.warn("🚫 Unsafe image detected. Deleting...");
      await getStorage().bucket(bucketName).file(filePath).delete();
      logger.info("🗑️ Image deleted from Storage");
    } else
    {
      logger.info("✅ Image passed moderation");
    }
  } catch (err)
  {
    logger.error("❌ Vision API error:", err);
  }
});


// ✅ 3. Auto-ping receiver when a Peek is created
exports.autoPingReceiver = onDocumentCreated("peek_requests/{requestId}", async (event) =>
{
  const snapshot = event.data;
  if (!snapshot) return logger.error("❌ No data for new peek request");

  const data = snapshot.data();
  const requestId = event.params.requestId;
  const receiverId = data?.to;

  if (!receiverId) return logger.warn("⚠️ No receiver ID found in data");

  try
  {
    const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) return logger.warn(`⚠️ No FCM token found for user ${receiverId}`);

    await admin.messaging().send({
      notification: {
        title: "👁 Someone wants to Peek!",
        body: "Open the app to respond to the request.",
      },
      data: { requestId },
      token: fcmToken,
    });

    logger.info(`✅ Auto-ping sent to ${receiverId}`);
  } catch (err)
  {
    logger.error("❌ Auto-ping failed:", err);
  }
});


// ✅ 4. Scheduled cleanup for expired peek requests
// Runs every 30s (change to 1m for production)
exports.cleanupExpiredPeeks = onSchedule("every 30 seconds", async (event) =>
{
  const now = admin.firestore.Timestamp.now();

  const snapshot = await admin
    .firestore()
    .collection("peek_requests")
    .where("status", "==", "pending")
    .where("expiresAt", "<=", now)
    .get();

  logger.info(`⏳ Checking for expired peek requests — ${snapshot.size} found`);

  const batch = admin.firestore().batch();

  snapshot.forEach((doc) =>
  {
    batch.update(doc.ref, {
      status: "timeout",
      timeout: true,
      expiredAt: now,
    });
  });




  await batch.commit();
  logger.info("✅ Cleanup complete — expired peeks updated");
});
