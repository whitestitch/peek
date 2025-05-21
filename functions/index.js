// Firebase Cloud Functions for Peek (JavaScript)
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {onSchedule} = require("firebase-functions/v2/scheduler");


const admin = require("firebase-admin");
const vision = require("@google-cloud/vision");
const logger = require("firebase-functions/logger");
const {getStorage} = require("firebase-admin/storage");

// Initialize Firebase Admin SDK ONCE
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();
const visionClient = new vision.ImageAnnotatorClient();

/**
 * Finds a suitable, random, online, non-blocking recipient for a Peek.
 * THIS IS A COMPLEX FUNCTION YOU NEED TO TAILOR TO YOUR APP'S LOGIC.
 *
 * @param {string} senderUid - The UID of the user sending the Peek.
 * @param {string[]} previouslyAttemptedRecipientUids - UIDs already tried.
 * @return {Promise<string|null>} The UID of a potential recipient, or null.
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

  // TODO: Implement robust recipient finding logic.
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

/**
 * HTTP Callable Function to initiate a Peek request.
 */
exports.initiatePeekRequest = onCall(
    {region: "us-central1", timeoutSeconds: 60},
    async (request) => {
      if (!request.auth) {
        logger.error(
            "Unauthenticated call to initiatePeekRequest.");
        throw new HttpsError( // Use HttpsError for structured errors
            "unauthenticated",
            "The function must be called while authenticated.",
        );
      }
      const senderUid = request.auth.uid;

      logger.info(`Peek request initiated by sender: ${senderUid}`);

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
            const blockedSenderIds = (recipientData &&
            recipientData.blockedSenderIds) ?
            recipientData.blockedSenderIds : [];

            if (blockedSenderIds.includes(senderUid)) {
              logger.info(
                  `Recipient
                  ${potentialRecipientUid}
                  blocked sender ${senderUid}.`,
                  `Attempt ${attempt + 1}. Finding another.`,
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
        const peekRequestData = {
          senderUid, // Use senderUid from auth context
          receiverUid: recipientUid,
          status: "pending_acceptance",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromMillis(
              Date.now() + 1 * 60 * 60 * 1000, // Expires in 1 hour
          ),
        };

        await db.collection("peek_requests")
            .doc(peekRequestId)
            .set(peekRequestData);
        logger.info(`Peek request document created: ${peekRequestId}`);

        return {
          success: true,
          peekRequestId,
          message: "Peek request initiated successfully.",
        };
      } catch (error) {
        logger.error(
            "Unhandled error in initiatePeekRequest main logic:", error);
        if (error instanceof HttpsError) {
          throw error; // Re-throw if already an HttpsError
        }
        // For other types of errors, wrap them in HttpsError
        throw new HttpsError(
            "internal",
            error.message || "Function internal error. Please check logs.",

            // For security, avoid sending the full error.stack to the client.
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
    // For onCreate, event.data is the DocumentSnapshot
      const snapshot = event.data;
      if (!snapshot || !snapshot.data()) {
      // ================== CHANGE END HERE ======
        logger.error("autoPingReceiver: No data on new peek request.");
        return null;
      }

      async (event) => {
      // For onCreate, event.data is the DocumentSnapshot
        const snapshot = event.data;
        if (!snapshot || !snapshot.data()) {
          logger.error("autoPingReceiver: No data on new peek request.");
          return null;
        }

        const data = snapshot.data();
        const requestId = event.params.requestId;

        const receiverUid = (
          data && data.receiverUid) ? data.receiverUid : null;
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
        // eslint-disable-next-line max-len
          logger.warn(`autoPingReceiver: Recipient document ${receiverUid} not found.`);
          return null;
        }

        const recipientData = recipientDoc.data();
        const blockedSenderIds = (recipientData &&
        recipientData.blockedSenderIds) ?
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
        // await admin.messaging().send({
          const payload = {
            notification: {
              title: "👁 Someone wants to Peek!",
              body: "Open the app to respond to the request.",
            },
            data: {requestId, type: "peek_request"},
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
      };
    },
);

/**
 * Storage Trigger (v2): Moderates uploaded images.
 */
const PEEK_STORAGE_BUCKET =
  process.env.FIREBASE_STORAGE_BUCKET || admin.app().options.storageBucket;

exports.moderateImageUpload = onObjectFinalized(
    {bucket: PEEK_STORAGE_BUCKET, region: "us-central1"},
    async (event) => {
    // StorageObjectData is on event.data
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

      try { // Added try-catch for Vision API call
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
      const now = admin.firestore.Timestamp.now();
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
        // logger.info(`✅ Cleaned up ${querySnapshot.size} expired peeks.`);
        logger.info(`✅ Cleaned up ${expired.size} expired peeks.`);
      } catch (error) {
        logger.error("❌ Error committing expired peeks batch:", error);
      }
      return null;
    },
);
