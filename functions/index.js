// Firebase Cloud Functions for Peek (JavaScript)

const functions = require("firebase-functions/v2");
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
exports.initiatePeekRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    logger.error("Unauthenticated call to initiatePeekRequest.");
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }
  const senderUid = context.auth.uid;
  logger.info(`Peek request initiated by sender: ${senderUid}`);

  const MAX_RECIPIENT_FIND_ATTEMPTS = 5;
  let recipientUid = null;
  const attemptedRecipientUids = [];

  for (let attempt = 0; attempt < MAX_RECIPIENT_FIND_ATTEMPTS; attempt++) {
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

    const recipientDocRef = db.collection("users").doc(potentialRecipientUid);
    const recipientDoc = await recipientDocRef.get();

    if (recipientDoc.exists) {
      const recipientData = recipientDoc.data();
      const blockedSenderIds = (recipientData &&
        recipientData.blockedSenderIds) ?
        recipientData.blockedSenderIds : [];

      if (blockedSenderIds.includes(senderUid)) {
        logger.info(
            `Recipient ${potentialRecipientUid} blocked sender ${senderUid}. `,
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
        `Failed to find non-blocking recipient for sender ${senderUid}`,
        `after ${MAX_RECIPIENT_FIND_ATTEMPTS} attempts.`,
    );
    throw new functions.https.HttpsError(
        "not-found",
        "Could not find a Peek recipient. Please try again later.",
    );
  }

  logger.info(`Final recipient for sender ${senderUid}: ${recipientUid}`);

  const peekRequestId = db.collection("peek_requests").doc().id;
  const peekRequestData = {
    senderUid: senderUid,
    receiverUid: recipientUid,
    status: "pending_acceptance",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(
        Date.now() + 1 * 60 * 60 * 1000, // Expires in 1 hour
    ),
  };

  await db.collection("peek_requests").doc(peekRequestId).set(peekRequestData);
  logger.info(`Peek request document created: ${peekRequestId}`);

  return {
    success: true,
    peekRequestId: peekRequestId,
    message: "Peek request initiated successfully.",
  };
});

exports.autoPingReceiverOnRequestCreate = functions.firestore
    .onDocumentCreated("peek_requests/{requestId}", async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.error(
            "autoPingReceiver: No snapshot data in event for new peek request.",
        );
        return null;
      }

      const data = snapshot.data();
      const requestId = event.params.requestId;

      const receiverUid = (data && data.receiverUid) ?
      data.receiverUid : null;
      const senderUid = (data && data.senderUid) ? data.senderUid : null;

      if (!receiverUid || !senderUid) {
        logger.warn(
            `autoPingReceiver: Missing UIDs for req ${requestId}. Data:`,
            JSON.stringify(data),
        );
        return null;
      }

      const recipientDocRef = db.collection("users").doc(receiverUid);
      const recipientDoc = await recipientDocRef.get();

      if (recipientDoc.exists) {
        const recipientData = recipientDoc.data();
        const blockedSenderIds = (recipientData &&
        recipientData.blockedSenderIds) ?
        recipientData.blockedSenderIds : [];
        if (blockedSenderIds.includes(senderUid)) {
          logger.info(
              `autoPingReceiver: Recipient ${receiverUid} blocked sender`,
              `${senderUid}. Ping aborted for ${requestId}.`,
          );
          return null;
        }
      } else {
        logger.warn(
            `autoPingReceiver: Recipient document ${receiverUid} not found.`,
        );
        return null;
      }

      try {
        const userDocData = recipientDoc.data();
        const fcmToken = (userDocData && userDocData.fcmToken) ?
        userDocData.fcmToken : null;

        if (!fcmToken) {
          logger.warn(
              `autoPingReceiver: No FCM token for ${receiverUid}.`,
              "No ping.",
          );
          return null;
        }

        const payload = {
          notification: {
            title: "👁 Someone wants to Peek!",
            body: "Open the app to respond to the request.",
          },
          data: {requestId: requestId, type: "peek_request"},
          token: fcmToken,
        };
        await admin.messaging().send(payload);
        logger.info(
            `✅ autoPingReceiver: Ping sent to ${receiverUid}`,
            `for ${requestId}.`,
        );
      } catch (err) {
        logger.error(
            `❌ autoPingReceiver: Ping failed for ${receiverUid}:`,
            err,
        );
      }
      return null;
    });

/**
 * Storage Trigger (v2): Moderates uploaded images.
 */
const PEEK_STORAGE_BUCKET =
  process.env.FIREBASE_STORAGE_BUCKET || admin.app().options.storageBucket;

const storageTriggerOptions =
  PEEK_STORAGE_BUCKET ? {bucket: PEEK_STORAGE_BUCKET} : {};

exports.moderateImageUpload = functions.storage.onObjectFinalized(
    storageTriggerOptions,
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
            `moderateImageUpload: File ${filePath} not a Peek. Skipping.`,
        );
        return null;
      }

      const gcsUri = `gs://${bucketName}/${filePath}`;
      logger.info(`🔍 Moderating uploaded image: ${gcsUri}`);

      try {
        const [result] = await visionClient.safeSearchDetection(gcsUri);
        const detections = result.safeSearchAnnotation;

        if (!detections) {
          logger.warn(
              "🚫 Vision API returned no safeSearchAnnotation for:",
              gcsUri,
          );
          return null;
        }
        logger.info(`👁 SafeSearch results for ${gcsUri}:`, detections);

        const unsafeLevels = ["LIKELY", "VERY_LIKELY"];
        const isAdult = unsafeLevels.includes(detections.adult || "");
        const isViolent = unsafeLevels.includes(detections.violence || "");
        const isRacy = unsafeLevels.includes(detections.racy || "");

        if (isAdult || isViolent || isRacy) {
          let reasons = "";
          if (isAdult) reasons += "Adult ";
          if (isViolent) reasons += "Violent ";
          if (isRacy) reasons += "Racy ";
          logger.warn(
              `🚫 Unsafe image (${reasons.trim()}). Deleting:`,
              gcsUri,
          );
          await getStorage().bucket(bucketName).file(filePath).delete();
          logger.info(`🗑️ Image deleted from Storage: ${filePath}`);
        } else {
          logger.info(`✅ Image passed moderation: ${gcsUri}`);
        }
      } catch (err) {
        logger.error(`❌ Vision API error for ${gcsUri}:`, err);
      }
      return null;
    });

/**
 * Scheduled Function: Cleans up expired (timed-out) peek requests.
 */

exports.cleanupExpiredPeeks = functions.scheduler
    .onSchedule("every 5 minutes", async (event) => {
      const now = admin.firestore.Timestamp.now();
      const querySnapshot = await db
          .collection("peek_requests")
          .where("status", "==", "pending_acceptance")
          .where("expiresAt", "<=", now)
          .get();

      if (querySnapshot.empty) {
        logger.info("⏳ No expired peek requests found to cleanup.");
        return null;
      }
      logger.info(
          `⏳ Found ${querySnapshot.size} expired peeks to cleanup.`,
      );

      const batch = db.batch();
      querySnapshot.forEach((doc) => {
        logger.info(`Updating peek ${doc.id} to timed_out.`);
        batch.update(doc.ref, {
          status: "timeout",
          expiredAt: now,
        });
      });

      try {
        await batch.commit();
        logger.info(
            `✅ Cleanup complete: ${querySnapshot.size} peeks updated.`,
        );
      } catch (error) {
        logger.error("❌ Error committing expired peeks batch:", error);
      }
      return null;
    });
