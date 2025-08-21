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
    {
      region: "us-central1",
      timeoutSeconds: 60,
      enforceAppCheck: false,
    },
    async (request) => {
      logger.info("🚀 Function version: 2.0 - Anonymous Auth Fix");

      // Manual App Check verification.
      // In production, request.app will be defined.
      // For debug builds, we'll check for a specific flag from the client.
      if (!request.app && request.data.debug !== true) {
        logger.error(
            "🚨 Manual App Check failed. No valid token and not a debug call.", {
              hasAppCheckToken: !!request.app,
              debugFlag: request.data.debug,
            });
        throw new HttpsError(
            "unauthenticated",
            "The function must be called from a verified app.",
        );
      }

      logger.info("✅ Manual App Check passed or was bypassed for emulator.");

      logger.info("🔍 initiatePeekRequest called with:", {

        hasAuth: !!request.auth,
        authUid: request.auth && request.auth.uid,
        isEmulator: isEmulator(),
        senderUid: request.data && request.data.senderUid,
        emulatorMode: request.data && request.data.emulatorMode,
      });

      // let senderUid;

      if (!request.auth || !request.auth.uid) {
        logger.error(
            "❌ Function called without valid authentication context.", {
              auth: request.auth,
            });
        throw new HttpsError(
            "unauthenticated",
            "The function must be called while authenticated.",
        );
      }

      // If we reach this point, request.auth.uid is guaranteed to exist.
      // We can declare and initialize senderUid as a constant here.
      const senderUid = request.auth.uid;

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

            // 🔧 NEW: Check if recipient is banned/restricted
            const reputation = recipientData.reputation || {};
            const recipientStatus = reputation.status || "normal";

            // 🔧 FIX: Only block 'restricted' users, not 'flagged' users
            if (recipientStatus === "restricted") {
              logger.info(
                  `Recipient ${potentialRecipientUid} is ${recipientStatus} ` +
                  `(banned). Attempt ${attempt + 1}. Finding another.`,
              );
              continue;
            }

            // Check if recipient has blocked the sender
            const blockedSenderIds = (
            recipientData && recipientData.blockedSenderIds) ?
            recipientData.blockedSenderIds : [];

            if (blockedSenderIds.includes(senderUid)) {
              logger.info(
                  `Recipient ${potentialRecipientUid}
                  blocked sender ${senderUid}. ` +
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
              `Failed to find eligible recipient for sender ${senderUid} ` +
              `after ${MAX_RECIPIENT_FIND_ATTEMPTS} attempts. ` +
              `All users are either banned (restricted) or have blocked ` +
              `the sender.`,
          );
          throw new HttpsError(
              "not-found",
              "No eligible Peek recipients available at this time. " +
              "All users are either restricted or have blocked you. " +
              "Please try again later.",
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
              Date.now() + 60 * 1000, // 60 seconds for peek request phase
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

      // 🔒 NEW: Check if recipient is currently in an active peek session
      const activeSession = recipientData.activePeekSession || {};
      const isInSession = activeSession.isActive === true;
      const sessionRequestId = activeSession.requestId;
      const sessionStartTime = activeSession.startTime;

      if (isInSession && sessionRequestId && sessionStartTime) {
        // Check if session is not too old (max 30 minutes)
        const sessionAge = Date.now() - sessionStartTime.toMillis();
        const maxSessionAge = 30 * 60 * 1000; // 30 minutes in milliseconds

        if (sessionAge < maxSessionAge) {
          logger.info(
              `autoPingReceiver: Recipient ${receiverUid} is in active ` +
              `session (${sessionRequestId}). Skipping notification for ` +
              `${requestId}.`,
          );
          return null;
        } else {
          logger.info(
              `autoPingReceiver: Recipient ${receiverUid} has stale ` +
              `session (${sessionAge}ms old). Clearing and allowing ` +
              `notification.`,
          );
          // Clear stale session
          await recipientDocRef.update({
            "activePeekSession": null,
          });
        }
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
        const message = {
          // Visible alert content
          notification: {
            title: "👁 Someone wants to Peekio!",
            body: "Open the app to respond to the request.",
          },
          // Custom data for your app
          data: {
            requestId: requestId,
            type: "peek_request_received",
          },
          // Platform-specific configuration
          android: {
            priority: "high",
            notification: {
              // Must match the channel ID created in notification_service.dart
              channel_id: "peek_requests_channel",
            },
          },
          apns: {
            headers: {
              "apns-push-type": "alert",
              "apns-priority": "10",
            },
            payload: {
              aps: {
                alert: {
                  title: "NEW PEEK REQUEST!",
                  body: "Someone wants to peek at you! Tap to respond.",
                },
                sound: "default",
                badge: 1,
              },
            },
          },
          token: fcmToken,
        };

        await admin.messaging().send(message);
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

exports.moderateImageUpload = onObjectFinalized(
    {region: "us-central1"},
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

// When a receiver creates a reaction document, update sender stats and notify.

exports.onReactionCreated = onDocumentCreated(
    {
      document: "peek_requests/{requestId}/reactions/{uid}",
      region: "us-central1",
    },
    async (event) => {
      const snap = event.data;
      if (!snap) return null;
      const data = snap.data();
      if (!data) return null;

      const {requestId, uid: reactorUid} = event.params;
      const reaction = (
        data.type || data.reaction || "").toString().toLowerCase();
      if (!reaction) {
        logger.warn(`onReactionCreated: missing reaction type for
          ${requestId}/${reactorUid}`);
        return null;
      }

      const peekRef = db.collection("peek_requests").doc(requestId);
      const peekSnap = await peekRef.get();
      if (!peekSnap.exists) {
        logger.warn(`onReactionCreated: peek ${requestId} not found`);
        return null;
      }

      const peek = peekSnap.data() || {};

      // Identify both sides of this peek
      const originalRequesterUid =
        peek.senderUid || peek.originalSenderId || peek.requesterUid;
      const imageSenderUid =
        peek.senderId || peek.responderUid || peek.photoSenderUid;
      if (!originalRequesterUid || !imageSenderUid) {
        logger.warn(
            `onReactionCreated: missing participant UIDs on peek ${requestId}`);
        return null;
      }
      // Write the animation event to the OTHER participant
      const targetUid = (reactorUid === imageSenderUid) ?
        originalRequesterUid :
        imageSenderUid;

      const isLike = reaction ===
        "like" ||
        reaction === "liked" ||
        reaction === "❤️";

      const counterField = isLike ?
        "likesReceivedCount" : "dislikesReceivedCount";

      await db.runTransaction(async (tx) => {
        // 1) Increment stats for the PHOTO SENDER (the person being reacted to)
        const statsRef = db.collection("users").doc(imageSenderUid);
        tx.set(
            statsRef,
            {
              [counterField]: admin.firestore.FieldValue.increment(1),
              "lastReactionAt": admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );

        // 2) Create a reaction event for the OTHER participant
        const eventRef = db
            .collection("users").doc(targetUid)
            .collection("received_reactions").doc(requestId);

        tx.set(
            eventRef,
            {
              reactionType: reaction, // aligns with client naming
              peekRequestId: requestId,
              fromUid: reactorUid,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );

        // 3) Mirror reaction on the peek_request
        tx.set(
            peekRef,
            {
              reaction,
              reactionBy: reactorUid,
              reactionAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
      });

      logger.info(
          `✅ onReactionCreated: updated sender stats & event for ${requestId}`);
      return null;
    },
);

// Cloud Function to cancel/decline peek requests with admin privileges
exports.cancelPeekRequest = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 30,
      enforceAppCheck: false,
    },
    async (request) => {
      logger.info("🚀 cancelPeekRequest called");

      // Manual App Check verification
      if (!request.app && request.data.debug !== true) {
        logger.error("🚨 Manual App Check failed for cancelPeekRequest");
        throw new HttpsError(
            "unauthenticated",
            "The function must be called from a verified app.",
        );
      }

      logger.info("✅ Manual App Check passed for cancelPeekRequest");

      if (!request.auth || !request.auth.uid) {
        throw new HttpsError(
            "unauthenticated",
            "User must be authenticated to cancel peek requests.",
        );
      }

      const {requestId, reason} = request.data;
      if (!requestId) {
        throw new HttpsError(
            "invalid-argument",
            "requestId is required.",
        );
      }

      try {
        const peekRef = db.collection("peek_requests").doc(requestId);
        const peekSnap = await peekRef.get();

        if (!peekSnap.exists) {
          throw new HttpsError(
              "not-found",
              "Peek request not found.",
          );
        }

        const userId = request.auth.uid;

        // Determine the cancellation reason and update accordingly
        let statusUpdate;
        if (reason === "receiver_cancelled") {
          statusUpdate = {
            "status": "cancelled_by_receiver",
            "declinedAt": admin.firestore.FieldValue.serverTimestamp(),
            "cancelledBy": userId,
          };
        } else if (reason === "sender_cancelled") {
          statusUpdate = {
            "status": "cancelled_by_sender",
            "cancelledAt": admin.firestore.FieldValue.serverTimestamp(),
            "cancelledBy": userId,
          };
        } else {
          statusUpdate = {
            "status": "cancelled",
            "cancelledAt": admin.firestore.FieldValue.serverTimestamp(),
            "cancelledBy": userId,
          };
        }

        await peekRef.update(statusUpdate);

        logger.info(
            `✅ Peek request ${requestId} cancelled successfully by ${userId} ` +
            `with reason: ${reason}`);

        return {
          success: true,
          message: "Peek request cancelled successfully",
          requestId: requestId,
          status: statusUpdate.status,
        };
      } catch (error) {
        logger.error(`❌ Error cancelling peek request ${requestId}: ${error}`);
        throw new HttpsError(
            "internal",
            "Failed to cancel peek request.",
        );
      }
    },
);
