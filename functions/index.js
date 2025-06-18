const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {onSchedule} = require("firebase-functions/v2/scheduler");

const admin = require("firebase-admin");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const vision = require("@google-cloud/vision");
const logger = require("firebase-functions/logger");
const {getStorage} = require("firebase-admin/storage");

// Initialize Firebase Admin SDK ONCE
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();
const visionClient = new vision.ImageAnnotatorClient();

const isEmulator = () => {
  return process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.NODE_ENV === "development";
};


/**
// The UID of the user initiating the peek request.
  @param {string} senderUid
  @param {Array<string>} previouslyAttemptedRecipientUids
  @return {Promise<string|null>}
 */
async function findPotentialRecipient(
    senderUid,
    previouslyAttemptedRecipientUids,
) {
  const attemptedStr = previouslyAttemptedRecipientUids.join(", ");
  logger.info(
      `Finding recipient (sender: ${senderUid},`,
      `attempted: ${attemptedStr})`,
  );

  const usersSnapshot = await db.collection("users").limit(50).get();
  const potentialRecipients = [];
  usersSnapshot.forEach((doc) => {
    if (
      doc.id !== senderUid &&
      !previouslyAttemptedRecipientUids.includes(doc.id)
    ) {
      potentialRecipients.push(doc.id);
    }
  });

  if (potentialRecipients.length === 0) {
    logger.warn("No potential recipients found.");
    return null;
  }
  const randomIndex = Math.floor(Math.random() * potentialRecipients.length);
  return potentialRecipients[randomIndex];
}

exports.initiatePeekRequest = onCall(
    {region: "us-central1", timeoutSeconds: 60},
    async (request) => {
      logger.info("🔍 initiatePeekRequest called with:", {
        hasAuth: !!request.auth,
        authUid: request.auth && request.auth.uid,
        isEmulator: isEmulator(),
        senderUid: request.data && request.data.senderUid,
        emulatorMode: request.data && request.data.emulatorMode,
      });

      let senderUid;

      try {
      // In emulator mode with emulatorMode flag, skip auth check entirely
        if (isEmulator() &&
          request.data && request.data.emulatorMode && request.data.senderUid) {
          senderUid = request.data.senderUid;
          logger.info(
              "🔧 Emulator mode bypass - using senderUid directly:", senderUid);
        } else if (request.auth && request.auth.uid) {
          senderUid = request.auth.uid;
          logger.info("✅ Using request.auth.uid:", senderUid);
        } else if (isEmulator() && request.data && request.data.senderUid) {
        // Fallback for emulator without explicit flag
          senderUid = request.data.senderUid;
          logger.info("🔧 Emulator fallback - using senderUid:", senderUid);
        } else {
          logger.error("❌ No authentication context or senderUid provided");
          throw new HttpsError(
              "unauthenticated",
              "The function must be called while authenticated.",
          );
        }
      } catch (authError) {
        logger.error("Authentication check failed:", authError);
        if (authError instanceof HttpsError) {
          throw authError;
        }
        throw new HttpsError(
            "unauthenticated",
            "Authentication validation failed",
        );
      }

      logger.info(`📝 Processing peek request for user: ${senderUid}`);

      try {
        const MAX_RECIPIENT_FIND_ATTEMPTS = 5;
        let recipientUid = null;
        const attemptedRecipientUids = [];

        for (
          let attempt = 0; attempt < MAX_RECIPIENT_FIND_ATTEMPTS; attempt++) {
          const potentialRecipientUid = await findPotentialRecipient(
              senderUid,
              attemptedRecipientUids,
          );
          if (!potentialRecipientUid) {
            logger.warn(
                `Attempt ${attempt + 1}: No recipient for sender ${senderUid}.`,
            );
            continue;
          }
          attemptedRecipientUids.push(potentialRecipientUid);

          const recipientDocRef = db.collection("users")
              .doc(potentialRecipientUid);
          const recipientDoc = await recipientDocRef.get();

          if (recipientDoc.exists) {
            const recipientData = recipientDoc.data();
            const blockedSenderIds = (
            recipientData && recipientData.blockedSenderIds) ?
            recipientData.blockedSenderIds : [];

            if (blockedSenderIds.includes(senderUid)) {
              logger.info(
                  `Recipient
                  ${potentialRecipientUid} blocked sender ${senderUid}.`,
                  `Attempt
                  ${attempt + 1}. Finding another.`,
              );
              continue;
            } else {
              recipientUid = potentialRecipientUid;
              break;
            }
          } else {
            logger.warn(
                `Recipient doc ${potentialRecipientUid} not found. Skipping.`,
            );
          }
        }

        if (!recipientUid) {
          logger.error(
              `Failed to find non-blocking recipient for sender ${senderUid} ` +
          `after ${MAX_RECIPIENT_FIND_ATTEMPTS} attempts.`,
          );
          throw new HttpsError(
              "not-found",
              "Could not find a Peek recipient at this time. Please try again.",
          );
        }

        logger.info(`Final recipient for sender ${senderUid}: ${recipientUid}`);

        const peekRequestId = db.collection("peek_requests").doc().id;

        logger.info("🔧 Creating peekRequestData object...");

        const peekRequestData = {
          senderUid,
          receiverUid: recipientUid,
          status: "pending_acceptance",
          createdAt: FieldValue.serverTimestamp(),
          expiresAt: Timestamp.fromMillis(
              Date.now() + 1 * 60 * 60 * 1000,
          ),
        };

        logger.info("✅ peekRequestData created successfully:", peekRequestData);

        await db.collection("peek_requests")
            .doc(peekRequestId).set(peekRequestData);
        logger.info(`✅ Peek request document created: ${peekRequestId}`);

        return {
          success: true,
          peekRequestId,
          message: "Peek request initiated successfully.",
        };
      } catch (error) {
        logger.error(
            "Unhandled error in initiatePeekRequest main logic:", error);

        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError(
            "internal",
            error.message || "Function internal error. Please check logs.",
            {
              originalErrorName: error.name,
              originalErrorMessage: error.message,
            },
        );
      }
    },
);

exports.autoPingReceiverOnRequestCreate = onDocumentCreated(
    {document: "peek_requests/{requestId}", region: "us-central1"},
    async (event) => {
      const snapshot = event.data;
      if (!snapshot || !snapshot.data()) {
        logger.error("autoPingReceiver: No data on new peek request.");
        return null;
      }

      const data = snapshot.data();
      const requestId = event.params.requestId;

      const receiverUid = (data && data.receiverUid) ? data.receiverUid : null;
      const senderUid = (data && data.senderUid) ? data.senderUid : null;

      if (!receiverUid || !senderUid) {
        logger.warn(
            `autoPingReceiver: Missing UIDs for req ${requestId}.`,
            `Data: ${JSON.stringify(data)}`,
        );
        return null;
      }

      const recipientDocRef = db.collection("users").doc(receiverUid);
      const recipientDoc = await recipientDocRef.get();

      if (!recipientDoc.exists) {
        logger.warn(`
          autoPingReceiver: Recipient document ${receiverUid} not found.`);
        return null;
      }

      const recipientData = recipientDoc.data();
      const blockedSenderIds = (
      recipientData && recipientData.blockedSenderIds) ?
      recipientData.blockedSenderIds : [];

      if (blockedSenderIds.includes(senderUid)) {
        logger.info(
            `autoPingReceiver: Recipient ${receiverUid}`,
            `blocked sender ${senderUid}. Ping aborted for ${requestId}.`,
        );
        return null;
      }

      const fcmToken = (recipientData && recipientData.fcmToken) ?
      recipientData.fcmToken : null;

      if (!fcmToken) {
        logger.warn(
            `autoPingReceiver: No FCM token for ${receiverUid}. No ping.`,
        );
        return null;
      }

      try {
        const payload = {
          notification: { // Standard notification object
            title: "👁 Someone wants to Peek!",
            body: "Open the app to respond to the request.",
          },
          data: { // Your custom data
            requestId,
            type: "peek_request_received",
          },
          apns: { // Apple Push Notification Service specific payload
            payload: {
              aps: {
                alert: { // Ensures the alert is shown
                  title: "👁 Someone wants to Peek!",
                  body: "Open the app to respond to the request.",
                },
                sound: "default", // Standard sound
                badge: 1, // Optional: to set the app icon badge
                // silent background updates AND a visible notification.
                // If only for visible notification, 'alert' is key.
              },
            },
          },
          token: fcmToken,
        };
        await admin.messaging().send(payload);
        logger.info(
            `✅ autoPingReceiver: Ping sent to ${receiverUid}`,
            `for ${requestId}.`,
        );
      } catch (err) {
        logger.error(
            `❌ autoPingReceiver: Ping failed for ${receiverUid}:`, err,
        );
      }
      return null;
    },
);

const PEEK_STORAGE_BUCKET =
  process.env.FIREBASE_STORAGE_BUCKET || admin.app().options.storageBucket;

exports.moderateImageUpload = onObjectFinalized(
    {bucket: PEEK_STORAGE_BUCKET, region: "us-central1"},
    async (event) => {
      const fileData = event.data;
      if (!fileData || !fileData.name || !fileData.bucket) {
        logger.error("moderateImageUpload: Missing file data in event.");
        return null;
      }
      const filePath = fileData.name;
      const bucketName = fileData.bucket;

      if (!filePath.startsWith("peeks/")) {
        logger.info(
            `moderateImageUpload: File ${filePath} not a Peek. Skipping.`);
        return null;
      }

      const gcsUri = `gs://${bucketName}/${filePath}`;
      logger.info(`🔍 Moderating uploaded image: ${gcsUri}`);

      try {
        const [result] = await visionClient.safeSearchDetection(gcsUri);
        const detections = result.safeSearchAnnotation;
        if (!detections) {
          logger.warn(
              `🔍 No SafeSearch data for ${gcsUri}, skipping moderation.`);
          return null;
        }

        const unsafe = ["LIKELY", "VERY_LIKELY"];
        if (
          (detections.adult && unsafe.includes(detections.adult)) ||
        (detections.violence && unsafe.includes(detections.violence)) ||
        (detections.racy && unsafe.includes(detections.racy))
        ) {
          logger.warn(`🚫 Unsafe image detected. Deleting: ${gcsUri}`);
          await getStorage().bucket(bucketName).file(filePath).delete();
          logger.info(`🗑️ Deleted: ${filePath}`);
        } else {
          logger.info(`✅ Passed moderation: ${gcsUri}`);
        }
      } catch (error) {
        logger.error("❌ Vision API error for " + gcsUri + ":", error);
      }
      return null;
    },
);

exports.cleanupExpiredPeeks = onSchedule(
    {
      schedule: "every 5 minutes",
      region: "us-central1",
      timeZone: "Etc/UTC",
    },
    async (event) => {
      const now = Timestamp.now();
      const expired = await db.collection("peek_requests")
          .where("status", "==", "pending_acceptance")
          .where("expiresAt", "<=", now)
          .get();

      if (expired.empty) {
        logger.info("⏳ No expired peeks to cleanup.");
        return null;
      }
      logger.info(
          `⏳ Found ${expired.size} expired peeks to cleanup.`,
      );

      const batch = db.batch();
      expired.forEach((doc) => {
        batch.update(doc.ref, {status: "timeout", expiredAt: now});
      });
      try {
        await batch.commit();
        logger.info(`✅ Cleaned up ${expired.size} expired peeks.`);
      } catch (error) {
        logger.error("❌ Error committing expired peeks batch:", error);
      }
      return null;
    },
);
