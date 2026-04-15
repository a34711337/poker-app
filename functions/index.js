const functions = require("firebase-functions");
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

    const priceId = (req.body?.priceId || "").trim();

    if (!priceId) {
      return res.status(400).json({ error: "Missing priceId" });
    }

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

    const priceId = (req.body?.priceId || "").trim();

    if (!priceId) {
      return res.status(400).json({ error: "Missing priceId" });
    }

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