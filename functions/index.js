// functions/index.js
// Option A1 — Full backend for OnlyMens
// - Single admin.initializeApp()
// - Option A1 flow: allow purchase while not signed in; client calls validateAppleReceipt after sign-in to claim
// - Store subscription at users/{uid}.subscription and map originalTransactionId -> uid for App Store notifications
// - Includes AI helper callables (chat, voice, TTS), onboarding report, panic mode, affirmations, and usage limits

const {
  onCall,
  HttpsError,
  onRequest,
} = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fetch = require("node-fetch"); // keep for older Node runtimes; optional if native fetch available

// initialize once
admin.initializeApp();

// Secrets (create these in your environment)
const OPENAI_KEY = defineSecret("OPENAI_API_KEY");
const APPLE_SHARED_SECRET = defineSecret("APPLE_SHARED_SECRET");

// Limits / constants
const CHAT_HOURLY_LIMIT = 20;
const CHAT_DAILY_LIMIT = 200;
const VOICE_DAILY_LIMIT = 50;
const TTS_PREMIUM_SECONDS = 240;
const AFFIRMATION_DAILY_LIMIT = 3;
const PANIC_MODE_DAILY_LIMIT = 10;
const ONBOARDING_REPORT_DAILY_LIMIT = 5;

// Helpers
function getTodayDate() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function isDeepQuestion(message) {
  if (!message || typeof message !== "string") return false;
  const deepKeywords = [
    "urge",
    "triggered",
    "struggling",
    "relapse",
    "tempted",
    "feeling weak",
    "can't resist",
    "about to",
    "edge",
    "edging",
    "craving",
    "lonely",
    "stressed",
    "anxious",
    "depressed",
    "help",
    "addiction",
    "overcome",
    "improve",
    "how to",
    "what should",
    "can't stop",
    "giving up",
    "fight",
  ];
  const lower = message.toLowerCase();
  return deepKeywords.some((k) => lower.includes(k));
}

function getStreakContext(current, longest) {
  if (!current || current === 0) return `Starting fresh today.`;
  if (current === longest && current > 0) return `NEW RECORD: ${current} days.`;
  if (longest > 0 && current >= longest * 0.7)
    return `Approaching your record — ${longest - current} days to beat it.`;
  if (current >= 7) return `Building momentum at ${current} days.`;
  if (current >= 3) return `Early phase — day ${current}.`;
  return `Day ${current}. Every day counts.`;
}

// ============================================
// OpenAI chat function
// ============================================
exports.sendChatMessage = onCall({ secrets: [OPENAI_KEY] }, async (req) => {
  if (!req.auth)
    throw new HttpsError("unauthenticated", "You must be logged in.");
  const uid = req.auth.uid;
  const userMessage = req.data?.message;
  const conversationHistory = req.data?.conversationHistory || [];
  const currentStreak = req.data?.currentStreak || 0;
  const longestStreak = req.data?.longestStreak || 0;
  const isDeep =
    req.data?.isDeep !== undefined
      ? req.data.isDeep
      : isDeepQuestion(userMessage);

  if (!userMessage || typeof userMessage !== "string") {
    throw new HttpsError("invalid-argument", "Message is required.");
  }
  if (userMessage.length > 1000) {
    throw new HttpsError("invalid-argument", "Message too long (max 1000).");
  }

  // Rate limiting (basic)
  const now = new Date();
  const hourKey = `${now.getFullYear()}-${
    now.getMonth() + 1
  }-${now.getDate()}-${now.getHours()}`;
  const dayKey = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;

  const usageRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("aiModelData")
    .doc("usage");
  const usageDoc = await usageRef.get();
  let hourly = 0,
    daily = 0;
  if (usageDoc.exists) {
    const d = usageDoc.data();
    hourly = (d.hourly && d.hourly[hourKey]) || 0;
    daily = (d.daily && d.daily[dayKey]) || 0;
  }
  if (hourly >= CHAT_HOURLY_LIMIT)
    throw new HttpsError("resource-exhausted", "Hourly chat limit reached.");
  if (daily >= CHAT_DAILY_LIMIT)
    throw new HttpsError("resource-exhausted", "Daily chat limit reached.");

  // Build system prompt
  const hasHistory =
    Array.isArray(conversationHistory) && conversationHistory.length > 0;
  const systemPrompt = isDeep
    ? `You are OnlyMens, an advanced coach. Current streak: ${currentStreak}, longest: ${longestStreak}. ${getStreakContext(
        currentStreak,
        longestStreak
      )}`
    : `You are OnlyMens, a friendly AI coach. Current streak: ${currentStreak}, longest: ${longestStreak}. Keep answers concise.`;

  // Call OpenAI
  const apiKey = OPENAI_KEY.value();
  if (!apiKey) throw new HttpsError("internal", "AI service not configured.");

  try {
    const messages = [
      { role: "system", content: systemPrompt },
      ...conversationHistory,
      { role: "user", content: userMessage },
    ];

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages,
        max_tokens: isDeep ? 500 : 200,
        temperature: isDeep ? 0.85 : 0.8,
      }),
    });

    if (!resp.ok) {
      const body = await resp.text();
      console.error("OpenAI error", resp.status, body);
      throw new HttpsError("internal", "AI service unavailable.");
    }

    const json = await resp.json();
    const aiReply =
      json.choices?.[0]?.message?.content?.trim() ||
      "Sorry, something went wrong.";

    // Save conversation and increment usage
    const batch = admin.firestore().batch();
    const chatDocId = req.data.sessionId || new Date().toISOString();
    const chatRef = admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("aiModelData")
      .doc(chatDocId);
    batch.set(
      chatRef,
      {
        msgs: admin.firestore.FieldValue.arrayUnion(
          { role: "user", text: userMessage },
          { role: "ai", text: aiReply }
        ),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    batch.set(
      usageRef,
      {
        [`hourly.${hourKey}`]: admin.firestore.FieldValue.increment(1),
        [`daily.${dayKey}`]: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await batch.commit();

    return {
      reply: aiReply,
      sessionId: chatDocId,
      responseType: isDeep ? "deep" : "casual",
    };
  } catch (err) {
    console.error("sendChatMessage error", err);
    throw new HttpsError("internal", "Failed to generate reply.");
  }
});

// ============================================
// Voice chat (short responses)
// ============================================
exports.sendVoiceMessage = onCall({ secrets: [OPENAI_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required.");
  const uid = req.auth.uid;
  const userMessage = req.data?.message;
  if (!userMessage || typeof userMessage !== "string") {
    throw new HttpsError("invalid-argument", "Message required.");
  }

  // Daily limit
  const today = getTodayDate();
  const voiceUsageRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("voiceUsage")
    .doc(today);
  const doc = await voiceUsageRef.get();
  const count = doc.exists ? doc.data().messageCount || 0 : 0;
  if (count >= VOICE_DAILY_LIMIT)
    throw new HttpsError("resource-exhausted", "Daily voice limit reached.");

  const apiKey = OPENAI_KEY.value();
  if (!apiKey) throw new HttpsError("internal", "AI service not configured.");

  try {
    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "You are OnlyMens Voice Coach. Keep responses short, warm and direct.",
          },
          { role: "user", content: userMessage },
        ],
        max_tokens: 150,
        temperature: 0.9,
      }),
    });

    if (!resp.ok) {
      console.error("Voice OpenAI error", resp.status, await resp.text());
      throw new HttpsError("internal", "Voice service unavailable.");
    }
    const json = await resp.json();
    const aiReply = json.choices?.[0]?.message?.content?.trim() || "";

    await voiceUsageRef.set(
      {
        messageCount: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        date: today,
      },
      { merge: true }
    );

    return { reply: aiReply };
  } catch (err) {
    console.error("sendVoiceMessage error", err);
    throw new HttpsError("internal", "Failed to generate voice reply.");
  }
});

// ============================================
// TTS generation (returns base64 audio)
// ============================================
exports.generateTTS = onCall({ secrets: [OPENAI_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required.");
  const uid = req.auth.uid;
  const text = req.data?.text;
  const estimatedDuration = req.data?.estimatedDuration || 0;

  if (!text || typeof text !== "string")
    throw new HttpsError("invalid-argument", "Text required.");
  const today = getTodayDate();

  const voiceUsageRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("voiceUsage")
    .doc(today);
  const doc = await voiceUsageRef.get();
  const usedSeconds = doc.exists ? doc.data().ttsSecondsUsed || 0 : 0;
  if (usedSeconds >= TTS_PREMIUM_SECONDS) {
    return { useFallback: true, message: "Premium TTS limit reached." };
  }

  const apiKey = OPENAI_KEY.value();
  if (!apiKey)
    return { useFallback: true, message: "TTS service not configured." };

  try {
    const resp = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini-tts",
        voice: "fable",
        input: text,
        speed: 1.0,
      }),
    });

    if (!resp.ok) {
      console.error("TTS error", resp.status, await resp.text());
      return { useFallback: true, message: "TTS unavailable." };
    }

    const arrayBuffer = await resp.arrayBuffer();
    const b64 = Buffer.from(arrayBuffer).toString("base64");

    await voiceUsageRef.set(
      {
        ttsSecondsUsed: admin.firestore.FieldValue.increment(estimatedDuration),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        date: today,
      },
      { merge: true }
    );

    const remaining = Math.max(
      0,
      TTS_PREMIUM_SECONDS - (usedSeconds + estimatedDuration)
    );
    return {
      audioBase64: b64,
      useFallback: false,
      remainingSeconds: remaining,
    };
  } catch (err) {
    console.error("generateTTS error", err);
    return { useFallback: true, message: "TTS generation failed." };
  }
});

// ============================================
// Check premium TTS availability
// ============================================
exports.checkPremiumTTS = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required.");
  const uid = req.auth.uid;
  const today = getTodayDate();
  const ref = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("voiceUsage")
    .doc(today);
  const doc = await ref.get();
  const used = doc.exists ? doc.data().ttsSecondsUsed || 0 : 0;
  const remaining = Math.max(0, TTS_PREMIUM_SECONDS - used);
  return {
    canUsePremium: remaining > 0,
    remainingSeconds: remaining,
    maxSeconds: TTS_PREMIUM_SECONDS,
  };
});

// ============================================
// Affirmation generation (limited)
// ============================================
exports.generateAffirmation = onCall({ secrets: [OPENAI_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required.");
  const uid = req.auth.uid;
  const today = getTodayDate();

  const genRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("affirmations")
    .doc("generations");
  const doc = await genRef.get();
  const todayCount = doc.exists ? doc.data()[today] || 0 : 0;
  if (todayCount >= AFFIRMATION_DAILY_LIMIT)
    throw new HttpsError("resource-exhausted", "Affirmation limit reached.");

  const apiKey = OPENAI_KEY.value();
  if (!apiKey) throw new HttpsError("internal", "AI service not configured.");

  try {
    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "You are a supportive coach. Generate 6-8 short affirmations, one per line.",
          },
          {
            role: "user",
            content:
              "Generate EXACTLY 6 short affirmations, 5-8 words each, for someone recovering from pornography addiction. One per line, no numbering.",
          },
        ],
        max_tokens: 150,
        temperature: 0.8,
      }),
    });

    if (!resp.ok) {
      console.error("Affirmation OpenAI error", resp.status, await resp.text());
      throw new HttpsError("internal", "AI unavailable.");
    }
    const json = await resp.json();
    const generated = json.choices?.[0]?.message?.content?.trim() || "";

    await genRef.set(
      {
        [today]: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    const remainingToday = Math.max(
      0,
      AFFIRMATION_DAILY_LIMIT - (todayCount + 1)
    );
    return {
      affirmation: generated,
      remainingToday,
      generatedAt: new Date().toISOString(),
    };
  } catch (err) {
    console.error("generateAffirmation error", err);
    throw new HttpsError("internal", "Failed to generate affirmation.");
  }
});

exports.checkAffirmationLimit = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required.");
  const uid = req.auth.uid;
  const today = getTodayDate();
  const genRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("affirmations")
    .doc("generations");
  const doc = await genRef.get();
  const todayCount = doc.exists ? doc.data()[today] || 0 : 0;
  const remaining = Math.max(0, AFFIRMATION_DAILY_LIMIT - todayCount);
  return {
    canGenerate: remaining > 0,
    remainingToday: remaining,
    maxPerDay: AFFIRMATION_DAILY_LIMIT,
    resetsAt: "midnight",
  };
});

// ============================================
// Panic mode guidance (short, limited uses)
// ============================================
function buildPanicModePrompt(currentStreak, longestStreak) {
  const streakContext = getStreakContext(currentStreak, longestStreak);
  return `You are OnlyMens Crisis Coach. Current streak: ${currentStreak}. ${streakContext}. Provide a short, grounding, empowering message (3 paragraphs max) and a 2-3 sentence breathing grounding instruction. Respond in JSON: {"mainText":"...", "guidanceText":"..."};`;
}

function getFallbackPanicResponse(currentStreak) {
  const main =
    currentStreak > 0
      ? `You've held ${currentStreak} days of progress — that shows strength. This urge is temporary. Sit with it and breathe.`
      : `You chose to change. That first step matters. This feeling will pass.`;
  const guidance =
    "Slow breathing: in 4, hold 2, out 6. Notice thoughts, don't act on them. You're safe.";
  return {
    mainText: main,
    guidanceText: guidance,
    remainingUses: PANIC_MODE_DAILY_LIMIT,
    timestamp: new Date().toISOString(),
    isFallback: true,
  };
}

exports.generatePanicModeGuidance = onCall(
  { secrets: [OPENAI_KEY] },
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Login required.");
    const uid = req.auth.uid;
    const currentStreak = req.data?.currentStreak || 0;
    const longestStreak = req.data?.longestStreak || 0;
    const today = getTodayDate();

    const usageRef = admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("panicModeUsage")
      .doc(today);
    const doc = await usageRef.get();
    const todayCount = doc.exists ? doc.data().count || 0 : 0;
    if (todayCount >= PANIC_MODE_DAILY_LIMIT)
      throw new HttpsError(
        "resource-exhausted",
        "Daily panic mode limit reached."
      );

    const apiKey = OPENAI_KEY.value();
    if (!apiKey) return getFallbackPanicResponse(currentStreak);

    try {
      const systemPrompt = buildPanicModePrompt(currentStreak, longestStreak);
      const resp = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: systemPrompt },
            {
              role: "user",
              content: `Current streak: ${currentStreak}. I need urgent help.`,
            },
          ],
          max_tokens: 400,
          temperature: 0.85,
          response_format: { type: "json_object" },
        }),
      });

      if (!resp.ok) {
        console.error("panic OpenAI err", resp.status, await resp.text());
        return getFallbackPanicResponse(currentStreak);
      }

      const json = await resp.json();
      // Expecting the model to return JSON object string inside choices[0].message.content
      let aiReply = {};
      try {
        aiReply = JSON.parse(json.choices?.[0]?.message?.content || "{}");
      } catch (parseErr) {
        console.warn(
          "Failed to parse GPT panic JSON, using fallback",
          parseErr
        );
        return getFallbackPanicResponse(currentStreak);
      }

      await usageRef.set(
        {
          count: admin.firestore.FieldValue.increment(1),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          date: today,
        },
        { merge: true }
      );
      const remaining = Math.max(0, PANIC_MODE_DAILY_LIMIT - (todayCount + 1));

      return {
        mainText:
          aiReply.mainText || aiReply.main || "You're stronger than this urge.",
        guidanceText:
          aiReply.guidanceText ||
          aiReply.guidance ||
          "Breathe slowly. This will pass.",
        remainingUses: remaining,
        timestamp: new Date().toISOString(),
      };
    } catch (err) {
      console.error("generatePanicModeGuidance error", err);
      return getFallbackPanicResponse(currentStreak);
    }
  }
);

exports.checkPanicModeLimit = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required.");
  const uid = req.auth.uid;
  const today = getTodayDate();
  const doc = await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("panicModeUsage")
    .doc(today)
    .get();
  const count = doc.exists ? doc.data().count || 0 : 0;
  const remaining = Math.max(0, PANIC_MODE_DAILY_LIMIT - count);
  return {
    canUse: remaining > 0,
    remainingUses: remaining,
    maxPerDay: PANIC_MODE_DAILY_LIMIT,
  };
});

// ============================================
// Onboarding report (uses OpenAI)
// ============================================
function buildReportPrompt(frequency, effects, triggers, goals, goalDetails) {
  return `You are OnlyMens Coach. Generate a 3-4 paragraph motivational report for:
Frequency: ${frequency}
Effects: ${effects.length ? effects.join(", ") : "None"}
Triggers: ${triggers.length ? triggers.join(", ") : "None"}
Goals: ${goals.length ? goals.join(", ") : "None"}
${goalDetails ? `Details: ${goalDetails}` : ""}
Return JSON: {"insight":"...","estimatedDays":15}`;
}

exports.generateOnboardingReport = onCall(
  { secrets: [OPENAI_KEY] },
  async (req) => {
    const deviceId = req.data?.deviceId;
    const frequency = req.data?.frequency || "Unknown";
    const effects = req.data?.effects || [];
    const triggers = req.data?.triggers || [];
    const goals = req.data?.goals || [];
    const goalDetails = req.data?.goalDetails || "";

    if (!deviceId)
      throw new HttpsError("invalid-argument", "deviceId required.");
    const today = new Date().toISOString().split("T")[0];
    const usageRef = admin
      .firestore()
      .collection("report_usage")
      .doc(`${deviceId}_${today}`);
    const usageDoc = await usageRef.get();
    const count = usageDoc.exists ? usageDoc.data().count || 0 : 0;
    if (count >= ONBOARDING_REPORT_DAILY_LIMIT)
      throw new HttpsError("resource-exhausted", "Daily report limit reached.");

    const apiKey = OPENAI_KEY.value();
    if (!apiKey)
      return {
        insight: "Fallback: keep going",
        estimatedDays: 15,
        isFallback: true,
      };

    try {
      const sys = buildReportPrompt(
        frequency,
        effects,
        triggers,
        goals,
        goalDetails
      );
      const resp = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: sys },
            { role: "user", content: "Generate the report JSON" },
          ],
          max_tokens: 400,
          temperature: 0.8,
          response_format: { type: "json_object" },
        }),
      });

      if (!resp.ok) {
        console.error("report OpenAI err", resp.status, await resp.text());
        return {
          insight: "Fallback insight",
          estimatedDays: 15,
          isFallback: true,
        };
      }

      const json = await resp.json();
      let aiReport = {};
      try {
        aiReport = JSON.parse(json.choices?.[0]?.message?.content || "{}");
      } catch (parseErr) {
        console.warn("Failed to parse report JSON", parseErr);
        return {
          insight: "Fallback insight",
          estimatedDays: 15,
          isFallback: true,
        };
      }

      await usageRef.set(
        {
          count: admin.firestore.FieldValue.increment(1),
          lastUsed: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      await admin
        .firestore()
        .collection("reports")
        .add({
          deviceId,
          frequency,
          effects,
          triggers,
          goals,
          insight: aiReport.insight || "",
          estimatedDays: aiReport.estimatedDays || 15,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      return {
        insight: aiReport.insight || "",
        estimatedDays: aiReport.estimatedDays || 15,
        remainingToday: Math.max(
          0,
          ONBOARDING_REPORT_DAILY_LIMIT - (count + 1)
        ),
      };
    } catch (err) {
      console.error("generateOnboardingReport error", err);
      return {
        insight: "Fallback insight",
        estimatedDays: 15,
        isFallback: true,
      };
    }
  }
);

// ============================================
// Apple receipt verification flow (Option A1)
// - verifyReceiptWithApple: calls production first, then sandbox if needed
// - validateAppleReceipt callable: client calls after sign-in (or can pass userId)
// - when userId provided, write users/{uid}.subscription and map originalTransactionId -> uid
// ============================================
async function verifyReceiptWithApple(receiptData) {
  const productionUrl = "https://buy.itunes.apple.com/verifyReceipt";
  const sandboxUrl = "https://sandbox.itunes.apple.com/verifyReceipt";
  const payload = {
    "receipt-data": receiptData,
    password: APPLE_SHARED_SECRET.value(),
    "exclude-old-transactions": true,
  };

  async function postTo(url) {
    const r = await fetch(url, {
      method: "POST",
      body: JSON.stringify(payload),
      headers: { "Content-Type": "application/json" },
    });
    return r.json();
  }

  let json = await postTo(productionUrl);
  // 21007: sandbox receipt used in production endpoint
  if (json && json.status === 21007) {
    json = await postTo(sandboxUrl);
    json._appleEndpoint = "sandbox";
  } else {
    json._appleEndpoint = "production";
  }
  return json;
}

exports.validateAppleReceipt = onCall(async (req) => {
  const receiptData = req.data?.receiptData;
  const productId = req.data?.productId;
  const userId = req.data?.userId || (req.auth ? req.auth.uid : null); // optional userId or from auth

  if (!receiptData) return { isValid: false, message: "Missing receiptData" };

  try {
    const json = await verifyReceiptWithApple(receiptData);
    if (!json || json.status !== 0) {
      console.warn("Apple verify failed", json);
      return {
        isValid: false,
        message: `Apple verify failed: status ${json ? json.status : "null"}`,
      };
    }

    // Apple may return subscription history in latest_receipt_info or in_app
    const latestInfo = json.latest_receipt_info || json.in_app || [];
    // prefer entries that match productId
    let relevant = latestInfo;
    if (productId) {
      relevant = latestInfo.filter((t) => t.product_id === productId);
    }
    relevant = relevant.sort(
      (a, b) => Number(b.expires_date_ms || 0) - Number(a.expires_date_ms || 0)
    );
    const entry = relevant[0] || latestInfo[0];

    const subscription = {
      productId: entry ? entry.product_id : productId,
      originalTransactionId: entry ? entry.original_transaction_id : null,
      transactionId: entry ? entry.transaction_id : null,
      purchaseDateMs: entry ? Number(entry.purchase_date_ms || 0) : null,
      expiresDateMs: entry ? Number(entry.expires_date_ms || 0) : null,
      isTrialPeriod: entry ? entry.is_trial_period === "true" : false,
      isInIntroOfferPeriod: entry
        ? entry.is_in_intro_offer_period === "true"
        : false,
      autoRenewStatus: json.auto_renew_status || null,
      raw: json,
      lastValidatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // If userId provided, attach subscription to user and save mapping
    if (userId) {
      const userRef = admin.firestore().collection("users").doc(userId);
      await userRef.set({ subscription }, { merge: true });
      if (subscription.originalTransactionId) {
        // map originalTransactionId -> userId for server notifications
        await admin
          .firestore()
          .collection("apple_subscriptions_map")
          .doc(subscription.originalTransactionId)
          .set(
            {
              userId,
              productId: subscription.productId,
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
      }
    }

    return { isValid: true, subscription };
  } catch (err) {
    console.error("validateAppleReceipt error", err);
    return {
      isValid: false,
      message: "Server error during receipt validation",
    };
  }
});

// ============================================
// App Store Server Notification endpoint (HTTP)
// - Accepts new Server-to-Server notifications and updates user's subscription if we have mapping
// - Optionally: verify JWT for production (not implemented here — see Apple's docs)
// ============================================
exports.appStoreNotification = onRequest(async (req, res) => {
  try {
    const body = req.body || {};
    // Newer notifications include signedPayload (JWT). For production, verify signature using Apple's public key.
    // For simplicity: if signedPayload exists, decode payload (NO verification) — replace with real JWT verification in prod.
    let payload = body;
    if (body.signedPayload) {
      try {
        const parts = body.signedPayload.split(".");
        if (parts.length === 3) {
          const decoded = Buffer.from(parts[1], "base64").toString();
          payload = JSON.parse(decoded);
        }
      } catch (err) {
        console.warn("Failed to decode signedPayload", err);
        payload = body; // fallback
      }
    }

    // Attempt to derive originalTransactionId and latest_receipt_info
    const unified = payload.unifiedReceipt || payload || {};
    const latestInfo = unified.latest_receipt_info || unified.in_app || [];
    let originalTransactionId = null;
    let productId = null;
    let expiresDateMs = null;

    if (Array.isArray(latestInfo) && latestInfo.length) {
      const latest = latestInfo[latestInfo.length - 1];
      originalTransactionId =
        latest.original_transaction_id || latest.originalTransactionId;
      productId = latest.product_id || latest.productId;
      expiresDateMs = Number(
        latest.expires_date_ms || latest.expiresDateMs || 0
      );
    } else if (payload.originalTransactionId) {
      originalTransactionId = payload.originalTransactionId;
    }

    if (!originalTransactionId) {
      console.warn("No originalTransactionId in notification", body);
      return res.status(200).send("ok");
    }

    // Find mapped user
    const mapRef = admin
      .firestore()
      .collection("apple_subscriptions_map")
      .doc(originalTransactionId);
    const mapDoc = await mapRef.get();
    if (!mapDoc.exists) {
      console.warn(
        "No mapping found for originalTransactionId",
        originalTransactionId
      );
      return res.status(200).send("ok");
    }

    const { userId } = mapDoc.data();
    if (!userId) {
      console.warn("Mapping exists but no userId", originalTransactionId);
      return res.status(200).send("ok");
    }

    const userRef = admin.firestore().collection("users").doc(userId);
    const updateData = {
      "subscription.rawNotification": payload,
      "subscription.lastNotifiedAt":
        admin.firestore.FieldValue.serverTimestamp(),
    };
    if (expiresDateMs) updateData["subscription.expiresDateMs"] = expiresDateMs;
    if (payload.notification_type || payload.notificationType)
      updateData["subscription.lastNotificationType"] =
        payload.notification_type || payload.notificationType;

    await userRef.set(updateData, { merge: true });
    return res.status(200).send("ok");
  } catch (err) {
    console.error("appStoreNotification error", err);
    return res.status(500).send("error");
  }
});

// ============================================
// Simple testAuth callable (useful for client debug)
// ============================================
exports.testAuth = onCall(async (req) => {
  if (!req.auth)
    throw new HttpsError("unauthenticated", "User must be logged in");
  return {
    uid: req.auth.uid,
    email: req.auth.token ? req.auth.token.email : null,
    message: "Authentication successful",
  };
});
