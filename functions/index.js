const functions = require("firebase-functions");
const functionsV1 = require("firebase-functions/v1");
const admin = require("firebase-admin");
const Stripe = require("stripe");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function getStripeSecretKey() {
  const secret =
    process.env.STRIPE_SECRET_KEY ||
    process.env.STRIPE_SECRET ||
    "";

  if (!secret) {
    throw new Error("Missing STRIPE_SECRET_KEY");
  }

  return secret;
}

function getStripeWebhookSecret() {
  const secret =
    process.env.STRIPE_WEBHOOK_SECRET || "";

  if (!secret) {
    throw new Error("Missing STRIPE_WEBHOOK_SECRET");
  }

  return secret;
}

function getStripe() {
  return new Stripe(getStripeSecretKey(), {
    apiVersion: "2024-06-20",
  });
}

function getPriceIdForPlan(plan) {
  const priceMap = {
    host: process.env.STRIPE_HOST_PRICE_ID || "",
    stats: process.env.STRIPE_STATS_PRICE_ID || "",
    bundle: process.env.STRIPE_BUNDLE_PRICE_ID || "",
  };

  const priceId = priceMap[plan];

  if (!priceId) {
    throw new Error(`Missing Stripe price id for plan: ${plan}`);
  }

  return priceId;
}

function normalizeEmail(email) {
  return (email || "").toString().trim().toLowerCase();
}

function toTimestampOrNull(date) {
  if (!date) return null;
  return admin.firestore.Timestamp.fromDate(date);
}

function toDateFromUnix(seconds) {
  if (!seconds) return null;
  return new Date(seconds * 1000);
}

function extractProductName(product) {
  if (!product) return "";
  if (typeof product === "string") return product.trim();
  return (product.name || "").toString().trim();
}

async function inferPlanTypeFromSubscription(subscriptionId) {
  const stripe = getStripe();

  const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
    expand: ["items.data.price.product"],
  });

  const productNames = subscription.items.data
    .map((item) => extractProductName(item.price?.product))
    .map((name) => name.toLowerCase());

  const hasBundle = productNames.some((name) =>
    name.includes("bundle")
  );

  const hasHost = productNames.some((name) =>
    name.includes("host")
  );

  const hasStats = productNames.some((name) =>
    name.includes("stats")
  );

  if (hasBundle) {
    return { planType: "bundle", subscription };
  }

  if (hasHost && hasStats) {
    return { planType: "bundle", subscription };
  }

  if (hasHost) {
    return { planType: "host", subscription };
  }

  if (hasStats) {
    return { planType: "stats", subscription };
  }

  throw new Error(
    `Could not infer plan type from subscription ${subscriptionId}`
  );
}

async function findUserUidFromSession(session) {
  const clientReferenceId = (session.client_reference_id || "").toString().trim();

  if (clientReferenceId) {
    const userDoc = await db.collection("users").doc(clientReferenceId).get();
    if (userDoc.exists) {
      return clientReferenceId;
    }
  }

  const metadataUid = (session.metadata?.uid || "").toString().trim();
  if (metadataUid) {
    const userDoc = await db.collection("users").doc(metadataUid).get();
    if (userDoc.exists) {
      return metadataUid;
    }
  }

  const email =
    normalizeEmail(session.customer_details?.email) ||
    normalizeEmail(session.customer_email);

  if (!email) {
    return null;
  }

  const userSnap = await db
    .collection("users")
    .where("emailLower", "==", email)
    .limit(1)
    .get();

  if (userSnap.empty) {
    return null;
  }

  return userSnap.docs[0].id;
}

async function upsertStripeSubscriptionRecord({
  uid,
  subscription,
  planType,
}) {
  const currentPeriodEnd = toDateFromUnix(subscription.current_period_end);

  await db.collection("stripe_subscriptions").doc(subscription.id).set(
    {
      uid,
      planType,
      status: (subscription.status || "").toString(),
      stripeCustomerId: (subscription.customer || "").toString(),
      currentPeriodEnd: toTimestampOrNull(currentPeriodEnd),
      cancelAtPeriodEnd: subscription.cancel_at_period_end === true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function recomputeUserEntitlements(uid) {
  const subsSnap = await db
    .collection("stripe_subscriptions")
    .where("uid", "==", uid)
    .get();

  let hostExpiresAt = null;
  let statsExpiresAt = null;

  for (const doc of subsSnap.docs) {
    const data = doc.data() || {};
    const status = (data.status || "").toString();
    const planType = (data.planType || "").toString();
    const currentPeriodEnd = data.currentPeriodEnd;

    const isActive =
      status === "active" ||
      status === "trialing" ||
      status === "past_due";

    if (!isActive || !currentPeriodEnd) {
      continue;
    }

    const expiresAt = currentPeriodEnd.toDate
      ? currentPeriodEnd.toDate()
      : new Date(currentPeriodEnd);

    if (Number.isNaN(expiresAt.getTime())) {
      continue;
    }

    if (planType === "host" || planType === "bundle") {
      if (!hostExpiresAt || expiresAt > hostExpiresAt) {
        hostExpiresAt = expiresAt;
      }
    }

    if (planType === "stats" || planType === "bundle") {
      if (!statsExpiresAt || expiresAt > statsExpiresAt) {
        statsExpiresAt = expiresAt;
      }
    }
  }

  const now = new Date();

  const hasHost =
    hostExpiresAt && hostExpiresAt.getTime() > now.getTime();

  const hasStats =
    statsExpiresAt && statsExpiresAt.getTime() > now.getTime();

  const updateData = {
    role: hasHost ? "host" : "player",

    isHostPro: hasHost === true,
    isStatsPro: hasStats === true,

    hostProActive: hasHost === true,
    statsProActive: hasStats === true,

    hostExpiresAt: hasHost ? toTimestampOrNull(hostExpiresAt) : null,
    statsExpiresAt: hasStats ? toTimestampOrNull(statsExpiresAt) : null,

    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (hasHost) {
    updateData.hostActivatedAt = admin.firestore.FieldValue.serverTimestamp();
    updateData.hostLastPaidAt = admin.firestore.FieldValue.serverTimestamp();
  }

  if (hasStats) {
    updateData.statsActivatedAt = admin.firestore.FieldValue.serverTimestamp();
    updateData.statsLastPaidAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await db.collection("users").doc(uid).set(updateData, { merge: true });
}

async function recomputeAppleEntitlements(uid) {
  const subsSnap = await db
    .collection("apple_subscriptions")
    .where("ownerUid", "==", uid)
    .get();

  let hostExpiresAt = null;
  let statsExpiresAt = null;

  for (const doc of subsSnap.docs) {
    const data = doc.data() || {};
    const planType = (data.planType || "").toString();
    const expiresAtRaw = data.expiresAt;

    if (!expiresAtRaw) continue;

    const expiresAt = expiresAtRaw.toDate
      ? expiresAtRaw.toDate()
      : new Date(expiresAtRaw);

    if (Number.isNaN(expiresAt.getTime())) continue;

    if (planType === "host") {
      if (!hostExpiresAt || expiresAt > hostExpiresAt) {
        hostExpiresAt = expiresAt;
      }
    }

    if (planType === "stats") {
      if (!statsExpiresAt || expiresAt > statsExpiresAt) {
        statsExpiresAt = expiresAt;
      }
    }
  }

  const now = new Date();

  const hasHost =
    hostExpiresAt && hostExpiresAt.getTime() > now.getTime();

  const hasStats =
    statsExpiresAt && statsExpiresAt.getTime() > now.getTime();

  const updateData = {
    role: hasHost ? "host" : "player",

    isHostPro: hasHost === true,
    isStatsPro: hasStats === true,

    hostProActive: hasHost === true,
    statsProActive: hasStats === true,

    hostExpiresAt: hasHost
      ? admin.firestore.Timestamp.fromDate(hostExpiresAt)
      : null,

    statsExpiresAt: hasStats
      ? admin.firestore.Timestamp.fromDate(statsExpiresAt)
      : null,

    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (hasHost) {
    updateData.hostLastPaidAt =
      admin.firestore.FieldValue.serverTimestamp();
  }

  if (hasStats) {
    updateData.statsLastPaidAt =
      admin.firestore.FieldValue.serverTimestamp();
  }

  await db.collection("users").doc(uid).set(updateData, { merge: true });
}

async function syncSubscriptionById(subscriptionId, uidOverride = null) {
  const { planType, subscription } =
    await inferPlanTypeFromSubscription(subscriptionId);

  let uid = uidOverride;

  if (!uid) {
    const existingDoc = await db
      .collection("stripe_subscriptions")
      .doc(subscriptionId)
      .get();

    if (existingDoc.exists) {
      uid = (existingDoc.data()?.uid || "").toString().trim();
    }
  }

  if (!uid) {
    throw new Error(`Missing uid for subscription ${subscriptionId}`);
  }

  await upsertStripeSubscriptionRecord({
    uid,
    subscription,
    planType,
  });

  await recomputeUserEntitlements(uid);
}

exports.createHostCheckoutSession = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const authHeader = req.headers.authorization || "";
    const idToken = authHeader.startsWith("Bearer ")
      ? authHeader.substring(7)
      : "";

    if (!idToken) {
      return res.status(401).json({ error: "Missing auth token" });
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;
    const email = decodedToken.email || "";

    const priceId = getPriceIdForPlan("host");

    const stripe = getStripe();

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      payment_method_types: ["card"],
      customer_email: email || undefined,
      client_reference_id: uid,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      subscription_data: {
        metadata: { uid },
      },
      metadata: { uid },
      success_url: "https://tablescheduler.web.app/?checkout=success",
      cancel_url: "https://tablescheduler.web.app/?checkout=cancel",
    });

    return res.status(200).json({ url: session.url });
  } catch (error) {
    console.error("createHostCheckoutSession error:", error);
    return res.status(500).json({
      error: error.message || "Internal Server Error",
    });
  }
});

exports.createStatsCheckoutSession = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const authHeader = req.headers.authorization || "";
    const idToken = authHeader.startsWith("Bearer ")
      ? authHeader.substring(7)
      : "";

    if (!idToken) {
      return res.status(401).json({ error: "Missing auth token" });
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;
    const email = decodedToken.email || "";

    const priceId = getPriceIdForPlan("stats");

    const stripe = getStripe();

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      payment_method_types: ["card"],
      customer_email: email || undefined,
      client_reference_id: uid,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      subscription_data: {
        metadata: { uid },
      },
      metadata: { uid },
      success_url: "https://tablescheduler.web.app/?checkout=success",
      cancel_url: "https://tablescheduler.web.app/?checkout=cancel",
    });

    return res.status(200).json({ url: session.url });
  } catch (error) {
    console.error("createStatsCheckoutSession error:", error);
    return res.status(500).json({
      error: error.message || "Internal Server Error",
    });
  }
});

exports.createBundleCheckoutSession = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const authHeader = req.headers.authorization || "";
    const idToken = authHeader.startsWith("Bearer ")
      ? authHeader.substring(7)
      : "";

    if (!idToken) {
      return res.status(401).json({ error: "Missing auth token" });
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;
    const email = decodedToken.email || "";

    const priceId = getPriceIdForPlan("bundle");

    const stripe = getStripe();

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      payment_method_types: ["card"],
      customer_email: email || undefined,
      client_reference_id: uid,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      subscription_data: {
        metadata: {
          uid,
          planType: "bundle",
        },
      },
      metadata: {
        uid,
        planType: "bundle",
      },
      success_url: "https://tablescheduler.web.app/?checkout=success",
      cancel_url: "https://tablescheduler.web.app/?checkout=cancel",
    });

    return res.status(200).json({ url: session.url });
  } catch (error) {
    console.error("createBundleCheckoutSession error:", error);
    return res.status(500).json({
      error: error.message || "Internal Server Error",
    });
  }
});

exports.createCustomerPortalSession = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const authHeader = req.headers.authorization || "";

    const idToken = authHeader.startsWith("Bearer ")
      ? authHeader.substring(7)
      : "";

    if (!idToken) {
      return res.status(401).json({
        error: "Missing auth token",
      });
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;

    const subSnap = await db
      .collection("stripe_subscriptions")
      .where("uid", "==", uid)
      .limit(1)
      .get();

    if (subSnap.empty) {
      return res.status(404).json({
        error: "No subscription found",
      });
    }

    const stripeCustomerId =
      (subSnap.docs[0].data().stripeCustomerId || "").toString().trim();

    if (!stripeCustomerId) {
      return res.status(404).json({
        error: "Missing Stripe customer id",
      });
    }

    const stripe = getStripe();

    const portalSession = await stripe.billingPortal.sessions.create({
      customer: stripeCustomerId,
      return_url: "https://tablescheduler.web.app/",
    });

    return res.status(200).json({
      url: portalSession.url,
    });
  } catch (error) {
    console.error("createCustomerPortalSession error:", error);

    return res.status(500).json({
      error: error.message || "Internal Server Error",
    });
  }
});

exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];

  let event;

  try {
    const stripe = getStripe();
    const webhookSecret = getStripeWebhookSecret();

    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      webhookSecret
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    if (event.type === "checkout.session.completed") {
      const session = event.data.object;

      if ((session.mode || "").toString() !== "subscription") {
        return res.json({ received: true });
      }

      const subscriptionId = (session.subscription || "").toString().trim();
      if (!subscriptionId) {
        return res.json({ received: true });
      }

      const uid = await findUserUidFromSession(session);

      if (!uid) {
        console.error("No matching user found for checkout session:", session.id);
        return res.status(400).send("No matching user found");
      }

      await syncSubscriptionById(subscriptionId, uid);

      console.log("checkout.session.completed synced:", {
        uid,
        subscriptionId,
      });
    }

    if (event.type === "invoice.payment_succeeded") {
      const invoice = event.data.object;
      const subscriptionId = (invoice.subscription || "").toString().trim();

      if (subscriptionId) {
        await syncSubscriptionById(subscriptionId);
        console.log("invoice.payment_succeeded synced:", subscriptionId);
      }
    }

    if (event.type === "customer.subscription.updated") {
      const subscription = event.data.object;
      const subscriptionId = (subscription.id || "").toString().trim();

      if (subscriptionId) {
        await syncSubscriptionById(subscriptionId);
        console.log("customer.subscription.updated synced:", subscriptionId);
      }
    }

    if (event.type === "customer.subscription.deleted") {
      const subscription = event.data.object;
      const subscriptionId = (subscription.id || "").toString().trim();

      if (subscriptionId) {
        const subRef = db.collection("stripe_subscriptions").doc(subscriptionId);
        const subDoc = await subRef.get();

        if (subDoc.exists) {
          const uid = (subDoc.data()?.uid || "").toString().trim();

          await subRef.set(
            {
              status: "canceled",
              cancelAtPeriodEnd: true,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          if (uid) {
            await recomputeUserEntitlements(uid);
          }
        }
      }
    }

    return res.json({ received: true });
  } catch (err) {
    console.error("Webhook handler error:", err);
    return res.status(500).send("Webhook handler failed");
  }
});

exports.transferAppleSubscription = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method Not Allowed" });
    }

    const authHeader = req.headers.authorization || "";
    const idToken = authHeader.startsWith("Bearer ")
      ? authHeader.substring(7)
      : "";

    if (!idToken) {
      return res.status(401).json({ error: "Missing auth token" });
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);

    const newOwnerUid = decodedToken.uid;
    const newOwnerEmailLower = normalizeEmail(decodedToken.email || "");

    const oldEmailLower = normalizeEmail(req.body.oldEmail || "");
    const newEmailLower = normalizeEmail(req.body.newEmail || "");

    const originalTransactionId =
      (req.body.originalTransactionId || "").toString().trim();

    if (!oldEmailLower) {
      return res.status(400).json({ error: "Missing old email" });
    }

    if (!newEmailLower || newEmailLower !== newOwnerEmailLower) {
      return res.status(400).json({ error: "New email does not match current login account" });
    }

    if (!originalTransactionId) {
      return res.status(400).json({ error: "Missing original transaction id" });
    }

    const subRef = db
      .collection("apple_subscriptions")
      .doc(originalTransactionId);

    let oldOwnerUid = "";

    await db.runTransaction(async (tx) => {
      const subDoc = await tx.get(subRef);

      if (!subDoc.exists) {
        throw new Error("Subscription not found");
      }

      const data = subDoc.data() || {};

      oldOwnerUid = (data.ownerUid || "").toString().trim();
      const currentOwnerEmailLower =
        normalizeEmail(data.ownerEmailLower || "");

      if (currentOwnerEmailLower &&
          currentOwnerEmailLower !== oldEmailLower) {
        throw new Error("Old email does not match the subscription owner");
      }

      if (oldOwnerUid === newOwnerUid) {
        throw new Error("This subscription is already linked to this account");
      }

      tx.set(
        subRef,
        {
          ownerUid: newOwnerUid,
          ownerEmailLower: newOwnerEmailLower,

          previousOwnerUid: oldOwnerUid,
          previousOwnerEmailLower: currentOwnerEmailLower || oldEmailLower,

          transferFromEmailLower: oldEmailLower,
          transferToEmailLower: newOwnerEmailLower,

          transferredAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    if (oldOwnerUid) {
      await recomputeAppleEntitlements(oldOwnerUid);
    }

    await recomputeAppleEntitlements(newOwnerUid);

    return res.status(200).json({
      ok: true,
      fromEmail: oldEmailLower,
      toEmail: newOwnerEmailLower,
      originalTransactionId,
    });
  } catch (error) {
    console.error("transferAppleSubscription error:", error);

    return res.status(500).json({
      error: error.message || "Transfer failed",
    });
  }
});

async function getTokensForUserIds(userIds) {
  const tokenSet = new Set();

  for (const uid of userIds || []) {
    if (!uid) continue;

    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.data() || {};
    const tokens = Array.isArray(userData.fcmTokens)
      ? userData.fcmTokens
      : [];

    for (const token of tokens) {
      if (typeof token === "string" && token.trim()) {
        tokenSet.add(token.trim());
      }
    }
  }

  return [...tokenSet];
}

async function sendPush({ tokens, title, body, data, badge }) {
  if (!tokens || tokens.length === 0) {
    console.log("No FCM tokens found");
    return;
  }

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: title || "Poker Table Reservation",
      body: body || "",
    },
    data: data || {},
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
          ...(badge != null ? { badge } : {}),
        },
      },
    },
    android: {
      notification: {
        sound: "default",
      },
    },
  });
}

// 🔔 新桌子通知
exports.sendNewTablePush = functionsV1.firestore
  .document("tables/{tableId}")
  .onCreate(async (snap, context) => {
    const tableData = snap.data() || {};
    const tableId = context.params.tableId;

    const hostUid = (tableData.createdByUid || "").toString().trim();
    const hostName = (tableData.createdByName || "Host").toString().trim();

    if (!hostUid) {
      console.log("No hostUid found for new table");
      return null;
    }

    const usersSnap = await db
      .collection("users")
      .where("grantedHostIds", "array-contains", hostUid)
      .get();

    const targetUserIds = usersSnap.docs
      .map((doc) => doc.id)
      .filter((uid) => uid && uid !== hostUid);

    if (targetUserIds.length === 0) {
      console.log("No target users for new table:", tableId);
      return null;
    }

    const tokens = await getTokensForUserIds(targetUserIds);

    const tableName = (tableData.name || "New Table").toString();
    const stakes = (tableData.stakes || "").toString().trim();
    const location = (tableData.location || "").toString().trim();

    const bodyParts = [
      tableName,
      ...(stakes ? [stakes] : []),
      ...(location ? [location] : []),
    ];

    for (const userDoc of usersSnap.docs) {
      const targetUid = userDoc.id;

      if (!targetUid || targetUid === hostUid) {
        continue;
      }

      const userData = userDoc.data() || {};

      const tokens = Array.isArray(userData.fcmTokens)
        ? userData.fcmTokens.filter((t) => typeof t === "string" && t.trim())
        : [];

      if (tokens.length === 0) {
        continue;
      }

      const lang = (userData.languageCode || "en").toString();

      let title = `${hostName} created a new table`;

      if (lang === "zhTw") {
        title = `${hostName} 建立了一個新牌桌`;
      } else if (lang === "zhCn") {
        title = `${hostName} 创建了一个新牌桌`;
      } else if (lang === "ko") {
        title = `${hostName} 님이 새 테이블을 만들었습니다`;
      } else if (lang === "ja") {
        title = `${hostName} さんが新しいテーブルを作成しました`;
      } else if (lang === "de") {
        title = `${hostName} hat einen neuen Tisch erstellt`;
      } else if (lang === "fr") {
        title = `${hostName} a créé une nouvelle table`;
      } else if (lang === "ar") {
        title = `${hostName} أنشأ طاولة جديدة`;
      } else if (lang === "ru") {
        title = `${hostName} создал новый стол`;
      } else if (lang === "trk") {
        title = `${hostName} yeni bir masa oluşturdu`;
      } else if (lang === "es") {
        title = `${hostName} creó una nueva mesa`;
      } else if (lang === "it") {
        title = `${hostName} ha creato un nuovo tavolo`;
      } else if (lang === "pl") {
        title = `${hostName} utworzył nowy stół`;
      } else if (lang === "pt") {
        title = `${hostName} criou uma nova mesa`;
      } else if (lang === "th") {
        title = `${hostName} ได้สร้างโต๊ะใหม่`;
      } else if (lang === "id") {
        title = `${hostName} membuat meja baru`;
      } else if (lang === "hi") {
        title = `${hostName} ने नई टेबल बनाई`;
      } else if (lang === "bn") {
        title = `${hostName} একটি নতুন টেবিল তৈরি করেছে`;
      }

      await db.collection("notifications").add({
        targetUid,
        title,
        message: bodyParts.join(" · "),
        type: "new_table",
        tableId: tableId.toString(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });

      await sendPush({
        tokens,
        title,
        body: bodyParts.join(" · "),
        data: {
          type: "new_table",
          tableId: tableId.toString(),
        },
      });
    }

    return null;
  });

// 💬 聊天通知
exports.sendChatPush = functionsV1.firestore
  .document("direct_chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const msg = snap.data() || {};
    const chatId = context.params.chatId;

    const senderUid = (msg.senderUid || "").toString();
    const text = (msg.text || "").toString();

    if (!senderUid || !text.trim()) return null;

    const chatDoc = await db.collection("direct_chats").doc(chatId).get();
    const chatData = chatDoc.data() || {};
    const members = Array.isArray(chatData.memberUids)
      ? chatData.memberUids
      : [];

    const targets = members.filter((uid) => uid && uid !== senderUid);
    const tokens = await getTokensForUserIds(targets);

    let badge = 0;

    if (targets.length > 0) {
      const targetUid = targets[0];

      const chatDocFresh = await db
        .collection("direct_chats")
        .doc(chatId)
        .get();

      const chatDataFresh = chatDocFresh.data() || {};
      const unreadCounts = chatDataFresh.unreadCounts || {};

      badge = Number(unreadCounts[targetUid] || 0);
    }

    const senderDoc = await db.collection("users").doc(senderUid).get();
    const senderData = senderDoc.data() || {};
    const senderName =
      senderData.displayName || senderData.shortName || "New message";

    await sendPush({
      tokens,
      title: senderName,
      body: text.length > 80 ? `${text.substring(0, 80)}...` : text,
      data: {
        type: "chat",
        chatId,
      },
      badge,
    });

    return null;
  });

exports.sendFriendRequestPush = functionsV1.firestore
  .document("friend_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};

    const fromUid = (data.fromUid || "").toString();
    const toUid = (data.toUid || "").toString();

    if (!fromUid || !toUid) return null;

    const tokens = await getTokensForUserIds([toUid]);

    await sendPush({
      tokens,
      title: "New friend request",
      body: `${data.fromShortName || data.fromDisplayName || "Someone"} sent you a friend request`,
      data: {
        type: "friend_request",
        requestId: context.params.requestId,
        fromUid,
      },
    });

    return null;
  });

exports.verifyAppleSubscription = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method Not Allowed" });
    }

    const authHeader = req.headers.authorization || "";
    const idToken = authHeader.startsWith("Bearer ")
      ? authHeader.substring(7)
      : "";

    if (!idToken) {
      return res.status(401).json({ error: "Missing auth token" });
    }

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;

    const clientProductId = (req.body.productId || "").toString();
    const clientType = (req.body.type || "").toString();

    const serverVerificationData =
      (req.body.serverVerificationData ||
        req.body.verificationData ||
        "").toString();

    const localVerificationData =
      (req.body.localVerificationData || "").toString();

    function decodeJwtPayload(token) {
      const parts = token.split(".");
      if (parts.length < 2) return null;

      const payload = parts[1]
        .replace(/-/g, "+")
        .replace(/_/g, "/");

      const padded = payload + "=".repeat((4 - payload.length % 4) % 4);
      return JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
    }

    function getPlanType(productId, fallbackType) {
      const clean = (productId || "").toLowerCase();

      if (clean.includes("hostpro")) return "host";
      if (clean.includes("statspro")) return "stats";

      if (fallbackType === "host") return "host";
      if (fallbackType === "stats") return "stats";

      return "";
    }

    let productId = "";
    let originalTransactionId = "";
    let transactionId = "";
    let expiresAt = null;
    let environment = "";
    let source = "";

    // 1) StoreKit 2 / JWS
    const possibleJws = [serverVerificationData, localVerificationData]
      .find((v) => v && v.split(".").length >= 3) || "";

    if (possibleJws && possibleJws.split(".").length >= 3) {
      const payload = decodeJwtPayload(possibleJws);

      if (!payload) {
        return res.status(400).json({ error: "Invalid JWS payload" });
      }

      productId = (payload.productId || clientProductId || "").toString();
      originalTransactionId =
        (payload.originalTransactionId ||
          payload.transactionId ||
          req.body.purchaseId ||
          "").toString();

      transactionId =
        (payload.transactionId || req.body.purchaseId || "").toString();

      const expiresMs = Number(payload.expiresDate || 0);

      if (!expiresMs) {
        return res.status(400).json({
          error: "Missing expiresDate from Apple JWS",
          payloadKeys: Object.keys(payload),
        });
      }

      expiresAt = new Date(expiresMs);
      environment = (payload.environment || "").toString();
      source = "jws";
    }

    // 2) Old receipt fallback
    if (!expiresAt) {
      const receiptData = localVerificationData || serverVerificationData;

      if (!receiptData) {
        return res.status(400).json({ error: "Missing receipt data" });
      }

      const sharedSecret = process.env.APPLE_SHARED_SECRET || "";

      if (!sharedSecret) {
        return res.status(500).json({ error: "Missing APPLE_SHARED_SECRET" });
      }

      async function verifyReceipt(url) {
        const response = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            "receipt-data": receiptData,
            password: sharedSecret,
            "exclude-old-transactions": true,
          }),
        });

        return await response.json();
      }

      let appleResult = await verifyReceipt(
        "https://buy.itunes.apple.com/verifyReceipt"
      );

      if (appleResult.status === 21007) {
        appleResult = await verifyReceipt(
          "https://sandbox.itunes.apple.com/verifyReceipt"
        );
      }

      if (appleResult.status !== 0) {
        console.error("Apple receipt verification failed:", {
          status: appleResult.status,
          environment: appleResult.environment,
          productIdFromClient: clientProductId,
          purchaseIdFromClient: req.body.purchaseId,
          sourceFromClient: req.body.source,
          typeFromClient: req.body.type,
          receiptLength: receiptData.length,
          receiptStart: receiptData.substring(0, 40),
        });

        return res.status(400).json({
          error: "Apple receipt verification failed",
          status: appleResult.status,
          environment: appleResult.environment || "",
        });
      }

      const latest = Array.isArray(appleResult.latest_receipt_info)
        ? appleResult.latest_receipt_info
        : [];

      if (latest.length === 0) {
        return res.status(400).json({ error: "No subscription found" });
      }

      latest.sort((a, b) => {
        const aExp = Number(a.expires_date_ms || 0);
        const bExp = Number(b.expires_date_ms || 0);
        return bExp - aExp;
      });

      const item = latest[0];

      productId = (item.product_id || clientProductId || "").toString();
      originalTransactionId =
        (item.original_transaction_id || item.transaction_id || "").toString();
      transactionId = (item.transaction_id || "").toString();

      const expiresMs = Number(item.expires_date_ms || 0);
      expiresAt = new Date(expiresMs);
      environment = (appleResult.environment || "").toString();
      source = "receipt";
    }

    if (!originalTransactionId || !productId || !expiresAt) {
      return res.status(400).json({
        error: "Invalid Apple subscription data",
        productId,
        originalTransactionId,
      });
    }

    const planType = getPlanType(productId, clientType);

    if (planType !== "host" && planType !== "stats") {
      return res.status(400).json({
        error: "Unknown Apple product",
        productId,
        clientType,
      });
    }

    const now = new Date();
    const isActive = expiresAt.getTime() > now.getTime();

    const subRef = db
      .collection("apple_subscriptions")
      .doc(originalTransactionId);

    await db.runTransaction(async (tx) => {
      const subDoc = await tx.get(subRef);

      if (subDoc.exists) {
        const existingOwnerUid = (subDoc.data().ownerUid || "")
          .toString()
          .trim();

        if (existingOwnerUid && existingOwnerUid !== uid) {
          throw new Error(
            "This subscription is already linked to another account."
          );
        }
      }

      tx.set(
        subRef,
        {
          ownerUid: uid,
          ownerEmailLower: normalizeEmail(decodedToken.email || ""),
          productId,
          planType,
          originalTransactionId,
          transactionId,
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          isActive,
          environment,
          source,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    const userUpdate = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (planType === "host") {
      userUpdate.role = isActive ? "host" : "player";
      userUpdate.isHostPro = isActive;
      userUpdate.hostProActive = isActive;
      userUpdate.hostExpiresAt =
        admin.firestore.Timestamp.fromDate(expiresAt);

      if (isActive) {
        userUpdate.hostLastPaidAt =
          admin.firestore.FieldValue.serverTimestamp();
      }
    }

    if (planType === "stats") {
      userUpdate.isStatsPro = isActive;
      userUpdate.statsProActive = isActive;
      userUpdate.statsExpiresAt =
        admin.firestore.Timestamp.fromDate(expiresAt);

      if (isActive) {
        userUpdate.statsLastPaidAt =
          admin.firestore.FieldValue.serverTimestamp();
      }
    }

    await recomputeAppleEntitlements(uid);

    return res.status(200).json({
      ok: true,
      productId,
      planType,
      originalTransactionId,
      expiresAt: expiresAt.toISOString(),
      isActive,
      source,
    });
  } catch (error) {
    console.error("verifyAppleSubscription error:", error);
    return res.status(500).json({
      error: error.message || "Internal Server Error",
    });
  }
});