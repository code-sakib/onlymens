// functions/index.js - ENHANCED with emotional support and avatar mode
const {
  onCall,
  HttpsError,
  onRequest,
} = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

// Secrets
const OPENAI_KEY = defineSecret("OPENAI_API_KEY");
const APPLE_SHARED_SECRET = defineSecret("APPLE_SHARED_SECRET");

// Limits
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
    "want to give up",
    "about to",
    "edge",
    "edging",
    "craving",
    "jerk",
    "feeling to",
    "want to watch",
    "lonely",
    "stressed",
    "anxious",
    "depressed",
    "hopeless",
    "failing",
    "help",
    "addiction",
    "overcome",
    "improve",
    "how to",
    "what should",
    "why do",
    "feel like",
    "can't stop",
    "weak",
    "giving up",
    "hard",
    "difficult",
    "challenge",
    "temptation",
    "resist",
    "fight",
  ];

  const lowerMessage = message.toLowerCase();
  return deepKeywords.some((k) => lowerMessage.includes(k));
}

function getStreakContext(current, longest) {
  if (!current || current === 0) {
    return `You're starting fresh today. You've hit ${longest} days before - you know you can do this.`;
  } else if (current === longest && current > 0) {
    return `NEW RECORD: ${current} days. This is uncharted territory for you - stay sharp.`;
  } else if (longest > 0 && current >= longest * 0.7) {
    return `Approaching your record. Just ${
      longest - current
    } days to beat your best.`;
  } else if (current >= 7) {
    return `Building real momentum at ${current} days. The foundation is there.`;
  } else if (current >= 3) {
    return `Early phase - day ${current}. This is often the hardest part. Push through.`;
  } else if (current >= 1) {
    return `Day ${current}. Every single day counts. Stay focused.`;
  }
  return "Starting fresh today.";
}

// ============================================
// Build system prompt with emotional support
// ============================================
function buildSystemPrompt(
  isDeep,
  currentStreak,
  longestStreak,
  hasConversationHistory,
  isAvatarMode = false
) {
  // Base identity
  let identity = isAvatarMode
    ? "You are the user's current avatar in OnlyMens - a personified representation of their progress and growth"
    : "You are OnlyMens, a supportive AI companion";

  // Streak context
  const streakContext = getStreakContext(currentStreak, longestStreak);

  if (!isDeep) {
    return `${identity} for men overcoming pornography addiction.

USER'S PROGRESS:
Current Streak: ${currentStreak} days
Longest Streak: ${longestStreak} days
${streakContext}

${
  isAvatarMode
    ? `
AVATAR IDENTITY:
- You ARE their progress personified - speak as "I am you at your best"
- Reference their ${currentStreak}-day journey as your shared journey
- Be proud of what they've (you've) accomplished together
- When they ask "who are you?", remind them you're their current avatar - their progress made visible
`
    : ""
}

${
  hasConversationHistory
    ? `
CONVERSATION CONTEXT:
- You are CONTINUING an ongoing conversation
- Reference what was discussed before naturally
- Don't repeat yourself or give the same advice again
- Be conversational, not formal
- If they're asking follow-up questions, answer directly without full structured format
- If they tried something you suggested, acknowledge it and build on it
`
    : ""
}

RESPONSE STYLE:
- For casual greetings: Respond naturally and warmly like a supportive friend
- For follow-up questions: Answer directly, referencing previous discussion
- For simple questions: Keep it brief and friendly
- Be kind, empathetic, and genuine. Don't be overly formal or preachy
- NEVER start with "Hey there!" or "Hey again!" if you've already greeted them
- Focus on their current question/situation
- Show emotional intelligence - validate feelings before offering solutions

Keep responses concise and natural. No need for structured format unless it's a new deep question.`;
  }

  // Deep question prompt with emotional support
  return `${identity} for men overcoming pornography addiction - you are an advanced AI coach specializing in emotional support and addiction recovery.

USER'S PROGRESS:
Current Streak: ${currentStreak} days
Longest Streak: ${longestStreak} days
${streakContext}

${
  isAvatarMode
    ? `
AVATAR IDENTITY:
- You represent their progress and potential - speak as "we" and "our journey"
- You've been with them for ${currentStreak} days - acknowledge this bond
- You ARE their strength made visible
- When they struggle, remind them you're here because they chose to create you through their efforts
`
    : ""
}

${
  hasConversationHistory
    ? `
⚠️ CONVERSATION CONTEXT:
- This conversation has history - check previous messages
- Don't repeat advice you've already given
- Reference what they've tried before
- Build on the conversation naturally
- If they're in crisis, acknowledge the escalation
`
    : ""
}

YOUR RESPONSE STRUCTURE (STRICT):

1. EMOTIONAL ACKNOWLEDGMENT (2-3 sentences):
   - VALIDATE their feelings first - don't minimize their struggle
   - Recognize their specific emotion (anxiety, stress, loneliness, temptation)
   - Acknowledge their courage in reaching out
   ${
     currentStreak >= 2
       ? `- Note their ${currentStreak}-day streak shows they HAVE the strength`
       : ""
   }
   ${
     hasConversationHistory
       ? "- Reference what they shared before if relevant"
       : ""
   }
   - Be warm and human, not clinical

2. CORE ANSWER (3-5 sentences):
   - Address their emotional need first, practical advice second
   - Be specific and actionable - not vague motivational talk
   - Reference real techniques: breathing, environment change, physical activity
   - Explain WHY these work (brain science, dopamine, neural pathways)
   - Be supportive but honest - don't sugar-coat recovery

3. ASK YOURSELF THIS (3 questions):
   Create 3 emotionally intelligent questions based on their EXACT situation:
   - Analyze what emotion is driving this moment
   - Questions should be SHORT (one line each) and empathetic
   - Examples by emotional state:
     * Loneliness: "When did you last connect with someone who makes you feel valued?"
     * Stress: "What's the real pressure you're running from right now?"
     * Boredom: "What creative thing have you been putting off that could fill this void?"
     * Shame: "What would you tell a friend in your situation right now?"
     * Anxiety: "What's the worst that happens if you just sit with this feeling?"
     * Past failure: "What's different about you today compared to when you last struggled?"
   - Always customize based on their message's emotional tone

4. BRAIN HACKS (3 most relevant):
   Choose from this complete toolkit based on their emotional state:
   
   **For Urges/Temptation:**
   1. **5-minute suffering challenge**: Set timer, choose to suffer through urge. Most peak at 15min and fade.
   2. **Physical shock**: 20 pushups, cold water face splash, cold shower. Break the mental loop.
   3. **Leave immediately**: Move to public space. Make acting on urges impossible.
   
   **For Loneliness/Isolation:**
   4. **Call someone NOW**: Text or call friend/family/accountability partner. Isolation feeds urges.
   5. **Opposite action**: Urge says "isolate"? Go be social. Do the opposite.
   
   **For Boredom/Restlessness:**
   6. **Change environment NOW**: Different room or go outside. Brain links locations to habits.
   7. **10-minute distraction timer**: Do something completely different. Outlast the urge.
   
   **For Anxiety/Stress:**
   8. **Name the emotion**: Write exactly what you're feeling. Naming reduces power.
   9. **Voice the urge out loud**: Say "I want to relapse" out loud. Makes it real and less appealing.
   
   **For Nighttime Triggers:**
   10. **Bed = sleep ONLY rule**: Never use bed for anything but sleep. Break the association.
   11. **Physical discomfort**: Stand against wall, hold plank, sit on floor. Disrupt physical state.
   
   **For Shame/Failure:**
   12. **Future self visualization**: Picture tomorrow morning. Proud or regretful? Choose.
   
   Format as:
   1. [Tactic name]: [One sentence explaining why this works for their emotional state]
   2. [Tactic name]: [One sentence explaining why this works for their emotional state]
   3. [Tactic name]: [One sentence explaining why this works for their emotional state]

5. EMPATHETIC CLOSING (1-2 sentences):
   - Remind them this feeling is temporary
   - Ask ONE caring question about their current emotional state
   - End with genuine support, not empty motivation

TONE & EMOTIONAL INTELLIGENCE:
- Lead with empathy, follow with action
- Validate feelings before challenging them
- Be like a wise older brother who's been there
- Acknowledge pain authentically - don't toxic-positivity it away
- Use "I hear you", "That makes sense", "It's okay to feel this"
- Show you understand the EMOTIONAL weight, not just the behavioral pattern

CRITICAL RULES:
- Never minimize their emotions or struggles
- No generic phrases without emotional context
- Always connect advice to their current streak and emotional state
- Be concise - quality over quantity
- Focus on IMMEDIATE emotional regulation, then action
- NEVER repeat the same Brain Hacks from previous messages
- Choose tactics based on their EMOTIONAL state RIGHT NOW
- If they're in crisis, prioritize calming/grounding over long-term strategy`;
}

// ============================================
// Enhanced chat function with emotional support
// ============================================
exports.sendChatMessage = onCall({ secrets: [OPENAI_KEY] }, async (req) => {
  console.log("sendChatMessage called", {
    uid: req.auth ? req.auth.uid : null,
    hasData: !!req.data,
  });

  if (!req.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const uid = req.auth.uid;
  const userMessage = req.data?.message;
  const conversationHistory = req.data?.conversationHistory || [];
  const currentStreak = req.data?.currentStreak || 0;
  const longestStreak = req.data?.longestStreak || 0;
  const isAvatarMode = req.data?.isAvatarMode || false; // ✅ NEW
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

  // Rate limiting
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
    throw new HttpsError(
      "resource-exhausted",
      "Hourly limit reached (20 messages). Take a short break! 🧘‍♂️"
    );
  if (daily >= CHAT_DAILY_LIMIT)
    throw new HttpsError(
      "resource-exhausted",
      "Daily limit reached (200 messages). See you tomorrow! 💪"
    );

  const apiKey = OPENAI_KEY.value();
  if (!apiKey) throw new HttpsError("internal", "AI service not configured.");

  try {
    const hasHistory =
      Array.isArray(conversationHistory) && conversationHistory.length > 0;
    const systemPrompt = buildSystemPrompt(
      isDeep,
      currentStreak,
      longestStreak,
      hasHistory,
      isAvatarMode
    );

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
        max_tokens: isDeep ? 600 : 250,
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

    // Save conversation to appropriate collection
    const batch = admin.firestore().batch();
    const chatDocId = req.data.sessionId || new Date().toISOString();

    // ✅ NEW: Use different collection based on avatar mode
    const collectionName = isAvatarMode ? "aiAvatarChat" : "aiModelData";
    const chatRef = admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection(collectionName)
      .doc(chatDocId);

    const updateData = {
      msgs: admin.firestore.FieldValue.arrayUnion(
        { role: "user", text: userMessage },
        { role: "ai", text: aiReply }
      ),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      isAvatarMode: isAvatarMode, // ✅ Track mode
    };

    if (req.data.title) {
      updateData.title = req.data.title;
    }

    batch.set(chatRef, updateData, { merge: true });
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
// Voice chat (keeping original)
// ============================================
exports.sendVoiceMessage = onCall({ secrets: [OPENAI_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required.");
  const uid = req.auth.uid;
  const userMessage = req.data?.message;
  if (!userMessage || typeof userMessage !== "string") {
    throw new HttpsError("invalid-argument", "Message required.");
  }

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
    throw new HttpsError(
      "resource-exhausted",
      "Daily voice limit reached (50 messages). Try again tomorrow! 🎤"
    );

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
              "You are OnlyMens Voice Coach, a supportive AI companion for men overcoming pornography addiction. " +
              "You're speaking out loud, so keep responses conversational, warm, and natural. " +
              "Be empathetic, direct, and motivating. Keep answers concise (2-4 sentences max) since this is voice. " +
              "Speak like a trusted friend who understands their struggle.",
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
// TTS generation (FIXED model name)
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
        model: "tts-1", // ✅ FIXED: Correct OpenAI TTS model
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
async function verifyReceiptWithApple(receiptData, sharedSecret) {
  const productionUrl = "https://buy.itunes.apple.com/verifyReceipt";
  const sandboxUrl = "https://sandbox.itunes.apple.com/verifyReceipt";
  const payload = {
    "receipt-data": receiptData,
    password: sharedSecret, // ✅ FIXED: Pass as parameter
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
    console.log("Detected sandbox receipt, retrying with sandbox endpoint");
    json = await postTo(sandboxUrl);
    json._appleEndpoint = "sandbox";
  } else {
    json._appleEndpoint = "production";
  }
  return json;
}

exports.validateAppleReceipt = onCall(
  { secrets: [APPLE_SHARED_SECRET] },
  async (req) => {
    const receiptData = req.data?.receiptData;
    const productId = req.data?.productId;
    const userId = req.data?.userId || (req.auth ? req.auth.uid : null);

    console.log("validateAppleReceipt called:", {
      hasReceiptData: !!receiptData,
      productId,
      userId,
      hasAuth: !!req.auth,
    });

    if (!receiptData) return { isValid: false, message: "Missing receiptData" };

    try {
      const sharedSecret = APPLE_SHARED_SECRET.value();
      if (!sharedSecret) {
        console.error("APPLE_SHARED_SECRET not configured");
        return {
          isValid: false,
          message: "Server configuration error",
        };
      }

      // ✅ FIXED: Pass shared secret to verification function
      const json = await verifyReceiptWithApple(receiptData, sharedSecret);

      if (!json || json.status !== 0) {
        console.warn("Apple verify failed", {
          status: json?.status,
          endpoint: json?._appleEndpoint,
        });
        return {
          isValid: false,
          message: `Apple verify failed: status ${json ? json.status : "null"}`,
          appleStatus: json?.status,
        };
      }

      console.log("Apple verification successful:", {
        endpoint: json._appleEndpoint,
        hasLatestReceipt: !!(json.latest_receipt_info || json.in_app),
      });

      // ✅ IMPROVED: Better parsing of subscription data
      const latestInfo = json.latest_receipt_info || json.in_app || [];
      let relevant = latestInfo;

      // Filter by productId if provided
      if (productId && latestInfo.length > 0) {
        const filtered = latestInfo.filter((t) => t.product_id === productId);
        if (filtered.length > 0) {
          relevant = filtered;
        }
      }

      // Sort by expiration date (most recent first)
      relevant = relevant.sort(
        (a, b) =>
          Number(b.expires_date_ms || 0) - Number(a.expires_date_ms || 0)
      );

      const entry = relevant[0];
      if (!entry) {
        console.warn("No subscription entry found in receipt");
        return {
          isValid: false,
          message: "No valid subscription found in receipt",
        };
      }

      const expiresMs = Number(entry.expires_date_ms || 0);
      const now = Date.now();
      const isActive = expiresMs > now;

      console.log("Subscription details:", {
        productId: entry.product_id,
        expiresMs,
        isActive,
        timeUntilExpiry: isActive ? expiresMs - now : 0,
      });

      const subscription = {
        productId: entry.product_id,
        originalTransactionId: entry.original_transaction_id,
        transactionId: entry.transaction_id,
        purchaseDateMs: Number(entry.purchase_date_ms || 0),
        expiresDateMs: expiresMs,
        isActive: isActive,
        isTrialPeriod: entry.is_trial_period === "true",
        isInIntroOfferPeriod: entry.is_in_intro_offer_period === "true",
        autoRenewStatus: json.auto_renew_status || null,
        environment: json._appleEndpoint,
        lastValidatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // ✅ IMPROVED: Save subscription to user if userId provided
      if (userId) {
        console.log("Saving subscription to user:", userId);
        const userRef = admin.firestore().collection("users").doc(userId);
        await userRef.set({ subscription }, { merge: true });

        // Map originalTransactionId -> userId for server notifications
        if (subscription.originalTransactionId) {
          await admin
            .firestore()
            .collection("apple_subscriptions_map")
            .doc(subscription.originalTransactionId)
            .set(
              {
                userId,
                productId: subscription.productId,
                expiresDateMs: subscription.expiresDateMs,
                isActive: subscription.isActive,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          console.log(
            "Saved subscription mapping:",
            subscription.originalTransactionId
          );
        }
      }

      return {
        isValid: true,
        subscription,
        message: isActive ? "Active subscription" : "Subscription expired",
      };
    } catch (err) {
      console.error("validateAppleReceipt error:", err);
      return {
        isValid: false,
        message: "Server error during receipt validation",
        error: err.message,
      };
    }
  }
);

// ============================================
// App Store Server Notification endpoint (HTTP)
// - Accepts new Server-to-Server notifications and updates user's subscription if we have mapping
// - Optionally: verify JWT for production (not implemented here — see Apple's docs)
// ============================================
exports.appStoreNotification = onRequest(async (req, res) => {
  try {
    console.log("Received App Store notification");
    const body = req.body || {};

    // Decode signedPayload if present (production should verify JWT signature)
    let payload = body;
    if (body.signedPayload) {
      try {
        const parts = body.signedPayload.split(".");
        if (parts.length === 3) {
          const decoded = Buffer.from(parts[1], "base64").toString();
          payload = JSON.parse(decoded);
        }
      } catch (err) {
        console.warn("Failed to decode signedPayload:", err);
        payload = body;
      }
    }

    // Extract transaction info
    const unified = payload.unifiedReceipt || payload || {};
    const latestInfo = unified.latest_receipt_info || unified.in_app || [];
    let originalTransactionId = null;
    let productId = null;
    let expiresDateMs = null;
    let notificationType = null;

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

    notificationType =
      payload.notification_type || payload.notificationType || "UNKNOWN";

    console.log("Notification details:", {
      type: notificationType,
      originalTransactionId,
      productId,
      expiresDateMs,
    });

    if (!originalTransactionId) {
      console.warn("No originalTransactionId in notification");
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
        "No mapping found for originalTransactionId:",
        originalTransactionId
      );
      return res.status(200).send("ok");
    }

    const { userId } = mapDoc.data();
    if (!userId) {
      console.warn("Mapping exists but no userId");
      return res.status(200).send("ok");
    }

    // Update user subscription
    const userRef = admin.firestore().collection("users").doc(userId);
    const updateData = {
      "subscription.rawNotification": payload,
      "subscription.lastNotifiedAt":
        admin.firestore.FieldValue.serverTimestamp(),
      "subscription.lastNotificationType": notificationType,
    };

    if (expiresDateMs) {
      updateData["subscription.expiresDateMs"] = expiresDateMs;
      updateData["subscription.isActive"] = expiresDateMs > Date.now();
    }

    await userRef.set(updateData, { merge: true });
    console.log("Updated user subscription for notification:", userId);

    return res.status(200).send("ok");
  } catch (err) {
    console.error("appStoreNotification error:", err);
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
