const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {getStorage} = require("firebase-admin/storage");
const vision = require("@google-cloud/vision");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// ✅ Cloud Vision client
const visionClient = new vision.ImageAnnotatorClient();

// ✅ 1. Push Notification when new Peek is created
exports.notifyOnPeekCreated = onDocumentCreated("peek_requests/{requestId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.error("❌ No data in event snapshot");
        return;
      }

      const data = snapshot.data();
      const imageUrl = data.imageUrl;
      const to = data.to;

      if (!imageUrl || !to) {
        logger.warn("❗️Missing 'imageUrl' or 'to' field.");
        return;
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

      try {
        await admin.messaging().send(payload);
        logger.info(`✅ Notification sent to: ${to.substring(0, 10)}...`);
      } catch (err) {
        logger.error("❌ Failed to send notification:", err);
      }
    });

// ✅ 2. Moderate image when uploaded to Storage
exports.moderateImageUpload = onObjectFinalized(
    {bucket: process.env.FIREBASE_STORAGE_BUCKET},
    async (event) => {
      const filePath = event.name;
      const bucketName = event.bucket;
      const gcsUri = `gs://${bucketName}/${filePath}`;

      logger.info(`🔍 Moderating uploaded image: ${gcsUri}`);

      try {
        const [result] = await visionClient.safeSearchDetection(gcsUri);
        const detections = result.safeSearchAnnotation;

        logger.info("👁 SafeSearch results:", detections);

        const unsafe = ["LIKELY", "VERY_LIKELY"];
        if (
          unsafe.includes(detections.adult) ||
          unsafe.includes(detections.violence) ||
          unsafe.includes(detections.racy)
        ) {
          logger.warn("🚫 Unsafe image detected. Deleting...");
          await getStorage().bucket(bucketName).file(filePath).delete();
          logger.info("🗑️ Image deleted from Storage");

          // Optional: Flag in Firestore or notify admin
        } else {
          logger.info("✅ Image passed moderation");
        }
      } catch (err) {
        logger.error("❌ Vision API failed:", err);
      }
    });
