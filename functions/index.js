/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Apple App Store Server Notifications V2
//
// Setup steps:
//   1. Deploy:  firebase deploy --only functions
//   2. Copy the function URL shown after deploy
//   3. App Store Connect → Your App → App Information
//      → App Store Server Notifications → Production Server URL  (paste URL)
//      → Sandbox Server URL  (same URL)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Decode a JWT payload without verifying the signature.
 * For production you should verify using Apple's JWKS endpoint.
 */
function decodeJwtPayload(token) {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return null;
    // Base64url → Base64 → JSON
    const padded = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = Buffer.from(padded, "base64").toString("utf8");
    return JSON.parse(json);
  } catch (e) {
    functions.logger.error("JWT decode error", e);
    return null;
  }
}

/**
 * Find the Firestore uid whose field matches the given value.
 * Apple sends `appAccountToken` (UUID you set at purchase time) OR we fall
 * back to looking up `subscriptionProductId` + `originalTransactionId`.
 *
 * If you want to use appAccountToken you must pass it when creating the
 * purchase param:
 *   PurchaseParam(productDetails: p, applicationUserName: FirebaseAuth.instance.currentUser!.uid)
 *
 * Otherwise we do a collection-wide query by originalTransactionId.
 */
async function findUidByAppAccountToken(token) {
  if (!token) return null;
  // appAccountToken is stored as-is when it equals the Firebase uid
  const snap = await db.collection("users").doc(token).get();
  return snap.exists ? token : null;
}

async function findUidByOriginalTransactionId(originalTransactionId) {
  if (!originalTransactionId) return null;
  const snap = await db
    .collection("users")
    .where("originalTransactionId", "==", originalTransactionId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].id;
}

function uniqueStrings(values) {
  return [...new Set(values.filter((value) => typeof value === "string" && value))];
}

function productPlanCap(productId) {
  if (!productId) return 1;
  return productId.includes("pro") ? 5 : 3;
}

function isTrialTransaction(transactionInfo = {}) {
  const offerType = Number(transactionInfo.offerType || 0);
  const offerDiscountType = transactionInfo.offerDiscountType || "";
  return offerType === 1 || offerDiscountType === "FREE_TRIAL";
}

function subscriptionStatusFromNotification(notificationType, renewalInfo, transactionInfo) {
  if (notificationType === "SUBSCRIBED" || notificationType === "DID_RENEW") {
    return isTrialTransaction(transactionInfo) ? "trial" : "active";
  }
  if (notificationType === "DID_CHANGE_RENEWAL_PREF") {
    return renewalInfo?.autoRenewStatus === 0 ? "canceled" : "active";
  }
  if (notificationType === "REVOKE") return "canceled";
  if (notificationType === "EXPIRED" || notificationType === "DID_FAIL_TO_RENEW") return "expired";
  if (notificationType === "DID_CHANGE_RENEWAL_STATUS" && renewalInfo?.autoRenewStatus === 0) return "expired";
  return "active";
}

async function collectMemberTokens(ownerUid, teamId) {
  const membersSnap = await db
    .collection("users")
    .doc(ownerUid)
    .collection("teams")
    .doc(teamId)
    .collection("members")
    .get();

  const memberUids = uniqueStrings(membersSnap.docs.map((doc) => doc.id));
  const tokenLists = await Promise.all(memberUids.map(async (uid) => {
    const devicesSnap = await db
      .collection("users")
      .doc(uid)
      .collection("devices")
      .get();
    return devicesSnap.docs.map((doc) => doc.id);
  }));

  return uniqueStrings(tokenLists.flat());
}

async function sendTeamEventNotification({
  ownerUid,
  teamId,
  title,
  body,
  data = {},
}) {
  const tokens = await collectMemberTokens(ownerUid, teamId);
  if (!tokens.length) {
    functions.logger.info("No member tokens found", {ownerUid, teamId});
    return;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, String(value)]),
    ),
    android: {
      priority: "high",
      notification: {
        channelId: "team_updates",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });

  functions.logger.info("Team notification sent", {
    ownerUid,
    teamId,
    successCount: response.successCount,
    failureCount: response.failureCount,
  });
}

exports.notifyMembersOnMatchCreated = functions.firestore
    .document("users/{ownerUid}/teams/{teamId}/matches/data")
    .onWrite(async (change, context) => {
      if (!change.after.exists) return null;

      const beforeMatches = change.before.exists ?
        (change.before.data().matches || []) : [];
      const afterMatches = change.after.data().matches || [];

      if (!Array.isArray(afterMatches) || afterMatches.length <= beforeMatches.length) {
        return null;
      }

      const newMatches = afterMatches.slice(beforeMatches.length);
      const teamDoc = await db
          .collection("users")
          .doc(context.params.ownerUid)
          .collection("teams")
          .doc(context.params.teamId)
          .get();
      const teamName = teamDoc.data()?.name || "球隊";

      await Promise.all(newMatches.map((match) => {
        const opponent = match.opponent || "新對手";
        const time = match.time || "";
        const venue = match.location || "";
        return sendTeamEventNotification({
          ownerUid: context.params.ownerUid,
          teamId: context.params.teamId,
          title: `🏀 ${teamName} 新增比賽`,
          body: `vs ${opponent}${time ? `・${time}` : ""}${venue ? `・${venue}` : ""}`,
          data: {
            type: "match_created",
            teamId: context.params.teamId,
            ownerUid: context.params.ownerUid,
          },
        });
      }));

      return null;
    });

exports.notifyMembersOnTrainingCreated = functions.firestore
    .document("users/{ownerUid}/teams/{teamId}/training/data")
    .onWrite(async (change, context) => {
      if (!change.after.exists) return null;

      const beforeTraining = change.before.exists ?
        (change.before.data().training || []) : [];
      const afterTraining = change.after.data().training || [];

      if (!Array.isArray(afterTraining) || afterTraining.length <= beforeTraining.length) {
        return null;
      }

      const newTraining = afterTraining.slice(beforeTraining.length);
      const teamDoc = await db
          .collection("users")
          .doc(context.params.ownerUid)
          .collection("teams")
          .doc(context.params.teamId)
          .get();
      const teamName = teamDoc.data()?.name || "球隊";

      await Promise.all(newTraining.map((training) => {
        const trainingTitle = training.title || "新訓練";
        const time = training.time || "";
        const venue = training.venue || "";
        return sendTeamEventNotification({
          ownerUid: context.params.ownerUid,
          teamId: context.params.teamId,
          title: `💪 ${teamName} 新增訓練`,
          body: `${trainingTitle}${time ? `・${time}` : ""}${venue ? `・${venue}` : ""}`,
          data: {
            type: "training_created",
            teamId: context.params.teamId,
            ownerUid: context.params.ownerUid,
          },
        });
      }));

      return null;
    });

// ─── Main webhook handler ─────────────────────────────────────────────────────

exports.appleSubscriptionWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const {signedPayload} = req.body;
    if (!signedPayload) {
      functions.logger.warn("No signedPayload in request body");
      res.status(400).send("Missing signedPayload");
      return;
    }

    // Decode outer notification envelope
    const notification = decodeJwtPayload(signedPayload);
    if (!notification) {
      res.status(400).send("Invalid JWT");
      return;
    }

    const notificationType = notification.notificationType; // e.g. "EXPIRED"
    const subtype = notification.subtype || "";

    // Decode inner signed transaction / renewal info
    const transactionInfo = notification.data?.signedTransactionInfo
      ? decodeJwtPayload(notification.data.signedTransactionInfo)
      : null;

    const renewalInfo = notification.data?.signedRenewalInfo
      ? decodeJwtPayload(notification.data.signedRenewalInfo)
      : null;

    functions.logger.info("Apple notification", {notificationType, subtype});

    if (!transactionInfo) {
      res.status(200).send("OK – no transaction info");
      return;
    }

    const {
      appAccountToken,
      originalTransactionId,
      expiresDate,       // ms epoch
      productId,
    } = transactionInfo;

    // Find Firebase uid
    let uid = await findUidByAppAccountToken(appAccountToken);
    if (!uid) {
      uid = await findUidByOriginalTransactionId(originalTransactionId);
    }

    if (!uid) {
      functions.logger.warn("Could not find user for notification", {appAccountToken, originalTransactionId});
      // Still return 200 so Apple doesn't retry endlessly
      res.status(200).send("OK – user not found");
      return;
    }

    const userRef = db.collection("users").doc(uid);
    const existingUserSnap = await userRef.get();
    const existingUser = existingUserSnap.data() || {};
    const planCap = productPlanCap(productId);
    const isTrial = isTrialTransaction(transactionInfo);
    const nextStatus = subscriptionStatusFromNotification(
      notificationType,
      renewalInfo,
      transactionInfo,
    );

    // ── Handle each notification type ────────────────────────────────────────

    if (notificationType === "DID_RENEW") {
      // Subscription successfully renewed – update expiry date
      const newExpiry = expiresDate
        ? admin.firestore.Timestamp.fromMillis(expiresDate)
        : null;
      const hadPaid = existingUser.hasEverPaidSubscription == true;
      const update = {
        originalTransactionId,
        subscriptionStatus: nextStatus,
        currentSubscriptionCap: planCap,
      };
      if (hadPaid || nextStatus !== "trial") {
        update.hasEverPaidSubscription = true;
      }
      if (nextStatus !== "trial") {
        update.retainedTeamCap = Math.max(existingUser.retainedTeamCap || 1, planCap);
      }
      if (newExpiry) update.subscriptionExpiryDate = newExpiry;
      await userRef.set(update, {merge: true});
      functions.logger.info("DID_RENEW – updated expiry", {uid});

    } else if (
      notificationType === "EXPIRED" ||
      notificationType === "DID_FAIL_TO_RENEW" ||
      notificationType === "REVOKE" ||
      (notificationType === "DID_CHANGE_RENEWAL_STATUS" &&
        renewalInfo?.autoRenewStatus === 0)
    ) {
      // Subscription lapsed – downgrade to free
      const hadPaid = existingUser.hasEverPaidSubscription == true;
      const update = {
        plan: "free",
        subscriptionStatus: notificationType === "REVOKE" ? "canceled" : "expired",
        currentSubscriptionCap: 1,
        subscriptionExpiryDate: admin.firestore.FieldValue.delete(),
        subscriptionProductId: admin.firestore.FieldValue.delete(),
      };
      if (!hadPaid) {
        update.retainedTeamCap = 1 + (existingUser.packTeams || 0);
      }
      await userRef.set(update, {merge: true});
      functions.logger.info("Subscription lapsed – downgraded to free", {uid, notificationType});

    } else if (notificationType === "SUBSCRIBED" || notificationType === "DID_CHANGE_RENEWAL_PREF") {
      // New subscription or plan change – update product id and expiry
      const plan = productId && productId.includes("pro") ? "pro" : "standard";
      const newExpiry = expiresDate
        ? admin.firestore.Timestamp.fromMillis(expiresDate)
        : null;
      const update = {
        plan,
        subscriptionProductId: productId,
        originalTransactionId,
        currentSubscriptionCap: planCap,
        trialUsed: existingUser.trialUsed === true || isTrial,
        subscriptionStatus: nextStatus,
      };
      if (!isTrial) {
        update.hasEverPaidSubscription = true;
        update.retainedTeamCap = Math.max(existingUser.retainedTeamCap || 1, planCap);
      }
      if (newExpiry) update.subscriptionExpiryDate = newExpiry;
      await userRef.set(update, {merge: true});
      functions.logger.info("SUBSCRIBED / plan change", {uid, plan, isTrial});

    } else {
      functions.logger.info("Unhandled notification type – no action", {notificationType});
    }

    res.status(200).send("OK");
  } catch (err) {
    functions.logger.error("Webhook handler error", err);
    res.status(500).send("Internal Server Error");
  }
});
