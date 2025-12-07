const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {onSchedule} = require("firebase-functions/v2/scheduler");

const admin = require("firebase-admin");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const vision = require("@google-cloud/vision");
const logger = require("firebase-functions/logger");

const {getStorage} = require("firebase-admin/storage");

// Apple App Store Receipt Validation URLs
const APPLE_PRODUCTION_VERIFY_URL =
  "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_SANDBOX_VERIFY_URL =
  "https://sandbox.itunes.apple.com/verifyReceipt";

// Status code indicating sandbox receipt was used in production
const APPLE_SANDBOX_RECEIPT_IN_PRODUCTION = 21007;

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
              "No eligible Peekio recipients available at this time. " +
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
              // 🎯 SYNC FIX: 5 seconds for testing phase (will be 60s later)
              Date.now() + 60 * 1000,
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

// Apple App Store Compliance: 24-hour moderation response
exports.monitorReportCompliance = onSchedule(
    {
      schedule: "every 1 hours",
      region: "us-central1",
      timeZone: "Etc/UTC",
    },
    async (event) => {
      logger.info("🛡️ Monitoring report compliance for Apple App Store...");

      const twentyFourHoursAgo = Timestamp.fromMillis(
          Date.now() - (24 * 60 * 60 * 1000),
      );

      // Find reports older than 24 hours that are still pending
      const overdueReports = await db.collection("reports")
          .where("status", "==", "pending_review")
          .where("reportTimestamp", "<=", twentyFourHoursAgo)
          .get();

      if (!overdueReports.empty) {
        logger.error(
            `🚨 CRITICAL: ${overdueReports.size} reports are overdue! ` +
            `Apple App Store compliance violation detected.`,
        );

        // Create critical alert
        await db.collection("admin_alerts").add({
          type: "compliance_violation",
          severity: "critical",
          count: overdueReports.size,
          // eslint-disable-next-line max-len
          message: "Reports older than 24 hours detected - Apple compliance violation",
          timestamp: FieldValue.serverTimestamp(),
          reportIds: overdueReports.docs.map((doc) => doc.id),
        });

        // Auto-escalate all overdue reports
        const batch = db.batch();
        overdueReports.forEach((doc) => {
          batch.update(doc.ref, {
            escalated: true,
            escalatedAt: FieldValue.serverTimestamp(),
            priority: "critical_overdue",
            complianceViolation: true,
          });
        });

        await batch.commit();
        logger.info(`⚡ Auto-escalated ${overdueReports.size} overdue reports`);
      } else {
        logger.info("✅ All reports within 24-hour compliance window");
      }

      // Check for reports approaching 20-hour mark (4-hour warning)
      const twentyHoursAgo = Timestamp.fromMillis(
          Date.now() - (20 * 60 * 60 * 1000),
      );

      const approachingDeadline = await db.collection("reports")
          .where("status", "==", "pending_review")
          .where("reportTimestamp", "<=", twentyHoursAgo)
          .where("escalated", "!=", true)
          .get();

      if (!approachingDeadline.empty) {
        logger.warn(
            // eslint-disable-next-line max-len
            `⚠️ WARNING: ${approachingDeadline.size} reports approaching 24-hour deadline`,
        );

        // Create warning alert
        await db.collection("admin_alerts").add({
          type: "deadline_warning",
          severity: "warning",
          count: approachingDeadline.size,
          message: "Reports approaching 24-hour deadline - action needed soon",
          timestamp: FieldValue.serverTimestamp(),
          reportIds: approachingDeadline.docs.map((doc) => doc.id),
        });
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
            `✅ Peekio request ${requestId}
            cancelled successfully by ${userId} ` +
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

/**
 * Validates an Apple App Store receipt with production/sandbox fallback.
 *
 * Apple's recommended approach (per App Store Review Guidelines):
 * 1. First, validate against the PRODUCTION App Store endpoint
 * 2. If status 21007 is returned ("sandbox receipt used in production"),
 *    automatically retry against the SANDBOX endpoint
 *
 * This ensures the app works correctly in both TestFlight/sandbox testing
 * and production environments.
 *
 * @param {string} receiptData - Base64-encoded receipt data from the app
 * @param {string} verifyUrl - Apple verification URL to use
 * @param {string} sharedSecret - Apple App-Specific Shared Secret
 * @return {Promise<Object>} - Apple's verification response
 */
async function verifyAppleReceipt(receiptData, verifyUrl, sharedSecret) {
  const requestBody = {
    "receipt-data": receiptData,
    "password": sharedSecret, // Required for auto-renewable subscriptions
    "exclude-old-transactions": true,
  };

  const response = await fetch(verifyUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    throw new Error(`Apple verification request failed: ${response.status}`);
  }

  return await response.json();
}

/**
 * Apple Receipt Validation Cloud Function
 *
 * Implements Apple's recommended receipt validation flow:
 * - Validates against production first
 * - Falls back to sandbox if status 21007 is returned
 * - Grants premium access only after successful validation
 * - Stores receipt validation details for audit purposes
 */
exports.validateAppleReceipt = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 60,
      enforceAppCheck: false,
      // Access the APPLE_SHARED_SECRET from Firebase Secrets
      secrets: ["APPLE_SHARED_SECRET"],
    },
    async (request) => {
      logger.info("🧾 validateAppleReceipt called");

      // App Check verification
      if (!request.app && request.data.debug !== true) {
        logger.error("🚨 App Check failed for validateAppleReceipt");
        throw new HttpsError(
            "unauthenticated",
            "The function must be called from a verified app.",
        );
      }

      // Authentication check
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError(
            "unauthenticated",
            "User must be authenticated to validate receipts.",
        );
      }

      // Get the shared secret from environment (populated by Firebase Secrets)
      const sharedSecret = process.env.APPLE_SHARED_SECRET;
      if (!sharedSecret) {
        logger.error("🚨 APPLE_SHARED_SECRET not configured");
        throw new HttpsError(
            "failed-precondition",
            "Server configuration error. Please contact support.",
        );
      }

      const userId = request.auth.uid;
      const {
        receiptData,
        productId,
        purchaseId,
        transactionDate,
      } = request.data;

      if (!receiptData) {
        throw new HttpsError(
            "invalid-argument",
            "receiptData is required.",
        );
      }

      logger.info(`🧾 Validating receipt for user ${userId}, ` +
        `product: ${productId}, purchase: ${purchaseId}`);

      try {
        // Step 1: Try production endpoint first (Apple's recommended approach)
        logger.info("🧾 Attempting production validation...");
        let verificationResult = await verifyAppleReceipt(
            receiptData,
            APPLE_PRODUCTION_VERIFY_URL,
            sharedSecret,
        );

        // Step 2: If sandbox receipt in production, retry with sandbox endpoint
        if (verificationResult.status === APPLE_SANDBOX_RECEIPT_IN_PRODUCTION) {
          logger.info(
              "🧾 Sandbox receipt detected (status 21007). " +
              "Retrying with sandbox endpoint...",
          );
          verificationResult = await verifyAppleReceipt(
              receiptData,
              APPLE_SANDBOX_VERIFY_URL,
              sharedSecret,
          );
        }

        // Log the verification status
        logger.info(
            `🧾 Apple verification status: ${verificationResult.status}`);

        // Status 0 means success
        if (verificationResult.status !== 0) {
          const errorMessage = getAppleErrorMessage(verificationResult.status);
          logger.error(
              `🧾 Receipt validation failed: ${errorMessage} ` +
              `(status: ${verificationResult.status})`,
          );

          // Store failed validation attempt for audit
          await db.collection("receipt_validations").add({
            userId,
            productId,
            purchaseId,
            status: "failed",
            appleStatus: verificationResult.status,
            errorMessage,
            timestamp: FieldValue.serverTimestamp(),
          });

          throw new HttpsError(
              "failed-precondition",
              `Receipt validation failed: ${errorMessage}`,
          );
        }

        // Step 3: Validation successful - extract receipt info
        const receipt = verificationResult.receipt || {};
        const inAppPurchases = receipt.in_app || [];

        // Verify the product was actually purchased
        const purchasedProduct = inAppPurchases.find(
            (p) => p.product_id === productId,
        );

        if (!purchasedProduct && productId) {
          logger.warn(
              `🧾 Product ${productId} not found in receipt. ` +
              `Available products: ${
                inAppPurchases.map((p) => p.product_id).join(", ")}`,
          );
          // Still proceed if receipt is valid - the product might be there
          // under a different format or this might be a restore
        }

        // Step 4: Grant premium access in Firestore
        const premiumData = {
          isPremium: true,
          premiumPlanId: productId || "unknown",
          premiumGrantedAt: FieldValue.serverTimestamp(),
          lastPurchaseId: purchaseId,
          lastPurchaseTimestamp: transactionDate ?
            Timestamp.fromMillisecondsSinceEpoch(parseInt(transactionDate)) :
            null,
          receiptValidated: true,
          receiptValidatedAt: FieldValue.serverTimestamp(),
          receiptEnvironment: verificationResult.environment || "unknown",
        };

        await db.collection("users").doc(userId).set(
            premiumData,
            {merge: true},
        );

        // Step 5: Store successful validation for audit trail
        await db.collection("receipt_validations").add({
          userId,
          productId,
          purchaseId,
          status: "success",
          appleStatus: 0,
          environment: verificationResult.environment,
          bundleId: receipt.bundle_id,
          applicationVersion: receipt.application_version,
          originalPurchaseDate: purchasedProduct ?
            purchasedProduct.original_purchase_date : null,
          timestamp: FieldValue.serverTimestamp(),
        });

        logger.info(
            `✅ Receipt validated and premium granted for user ${userId}. ` +
            `Environment: ${verificationResult.environment}`,
        );

        return {
          success: true,
          message: "Receipt validated successfully. Premium access granted.",
          environment: verificationResult.environment,
          productId: productId,
        };
      } catch (error) {
        logger.error(`❌ Error validating receipt: ${error.message}`);

        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            `Receipt validation failed: ${error.message}`,
        );
      }
    },
);

/**
 * Returns a human-readable error message for Apple receipt status codes.
 * Reference: https://developer.apple.com/documentation/appstorereceipts/status
 *
 * @param {number} status - Apple receipt status code
 * @return {string} - Human-readable error message
 */
function getAppleErrorMessage(status) {
  const errorMessages = {
    21000: "The request to the App Store was not made using HTTP POST.",
    21001: "This status code is no longer sent by the App Store.",
    21002: "The data in the receipt-data property was malformed or missing.",
    21003: "The receipt could not be authenticated.",
    21004: "The shared secret does not match the shared secret on file.",
    21005: "The receipt server is temporarily unable to provide the receipt.",
    21006: "This receipt is valid but the subscription has expired.",
    21007: "This receipt is from the test environment (sandbox).",
    21008: "This receipt is from the production environment.",
    21009: "Internal data access error.",
    21010: "The user account cannot be found or has been deleted.",
  };

  return errorMessages[status] || `Unknown error (status: ${status})`;
}
