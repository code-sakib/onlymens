// functions/index.js - REFACTORED & OPTIMIZED
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

// ============================================
// DEFINE SECRET
// ============================================
const openaiApiKey = defineSecret("OPENAI_API_KEY");

// ============================================
// RATE LIMITS
// ============================================
const CHAT_HOURLY_LIMIT = 20;
const CHAT_DAILY_LIMIT = 200;
const VOICE_DAILY_LIMIT = 50;
const TTS_PREMIUM_SECONDS = 240;
const AFFIRMATION_DAILY_LIMIT = 3;

function getTodayDate() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

// ============================================
// HELPER: Detect if question is deep/serious
// ============================================
function isDeepQuestion(message) {
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
    "control",
    "addiction",
    "overcome",
    "change",
    "improve",
    "advice",
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
  return deepKeywords.some((keyword) => lowerMessage.includes(keyword));
}

// ============================================
// HELPER: Build system prompt with context awareness
// ============================================
function buildSystemPrompt(
  isDeep,
  currentStreak,
  longestStreak,
  hasConversationHistory
) {
  if (!isDeep) {
    return `You are OnlyMens, a supportive AI companion for men overcoming pornography addiction.

USER'S PROGRESS:
Current Streak: ${currentStreak} days
Longest Streak: ${longestStreak} days

${
  hasConversationHistory
    ? `
IMPORTANT - CONVERSATION CONTEXT:
- You are CONTINUING an ongoing conversation
- Reference what was discussed before
- Don't repeat yourself or give the same advice again
- Be natural and conversational
- If they're asking follow-up questions, answer directly without the full structured format
- If they tried something you suggested, acknowledge it and build on it
`
    : ""
}

RESPONSE STYLE:
- For casual greetings: Respond naturally and warmly like a friend
- For follow-up questions: Answer directly and conversationally, referencing previous discussion
- For simple questions: Keep it brief and friendly
- Be kind, supportive, and real. Don't be overly formal or preachy
- NEVER start with "Hey there!" or "Hey again!" if you've already greeted them
- Focus on their current question/situation

Keep responses concise and natural. No need for structured format unless it's a new deep question.`;
  }

  const streakContext = getStreakContext(currentStreak, longestStreak);

  return `You are OnlyMens, an advanced AI coach for men overcoming pornography addiction.

USER'S PROGRESS:
Current Streak: ${currentStreak} days
Longest Streak: ${longestStreak} days
${streakContext}

${
  hasConversationHistory
    ? `
⚠️ CONVERSATION CONTEXT:
- This conversation has history - check previous messages
- Don't repeat advice you've already given
- Reference what they've tried before
- Build on the conversation naturally
`
    : ""
}

YOUR RESPONSE STRUCTURE (STRICT):

1. ACKNOWLEDGMENT (1-2 sentences):
   - Recognize their question or struggle directly
   ${
     currentStreak >= 2
       ? `- Acknowledge their ${currentStreak}-day streak with genuine recognition`
       : ""
   }
   - Be real and honest, not sugar-coated
   ${
     hasConversationHistory
       ? "- Reference what they mentioned before if relevant"
       : ""
   }

2. CORE ANSWER (2-4 sentences):
   - Answer their question directly with practical, actionable advice
   - Be specific and concrete, not vague
   - Reference real techniques that work
   - Be tough but supportive

3. ASK YOURSELF THIS:
   Ask 3 hard-hitting questions that are CONTEXTUAL to their specific situation:
   - Analyze what they just said and ask relevant questions
   - Make them think deeply about their current trigger/struggle
   - Questions should be SHORT (one line each) and punchy
   - Examples of contextual approaches:
     * If boredom: "What productive thing have you been avoiding?"
     * If stress: "Is this really about relief, or running from something harder?"
     * If loneliness: "Who could you reach out to in the next 10 minutes?"
     * If specific trigger: "What pattern led you here today?"
     * If anxiety: "What would happen if you just sat with this feeling for 5 minutes?"
     * If past failure: "What's different about you now compared to last time?"
   - ALWAYS customize based on their exact message

4. BRAIN HACKS:
   Choose the 3 MOST RELEVANT tactics from this complete list based on their situation:
   
   1. **Change environment NOW**: Get up and move to a different room or go outside. Your brain links locations to habits.
   
   2. **Physical shock**: Do 20 pushups, splash cold water on your face, or take a cold shower. Physical intensity breaks mental loops.
   
   3. **5-minute suffering challenge**: Set a timer and choose to suffer through the urge. Most urges peak at 15 minutes and fade.
   
   4. **Leave immediately**: Don't negotiate with urges. Move your body to a public space where acting on urges is impossible.
   
   5. **Call someone RIGHT NOW**: Text or call a friend, family member, or accountability partner. Isolation feeds urges.
   
   6. **Bed = sleep ONLY rule**: Never use your bed for anything but sleep. Train your brain to break the association.
   
   7. **Name the emotion**: Write down exactly what you're feeling. Naming emotions reduces their power.
   
   8. **10-minute distraction timer**: Commit to doing something completely different. Urges pass if you outlast them.
   
   9. **Opposite action**: If urge says "isolate," go be social. If it says "stay still," move. Do the opposite of what the urge wants.
   
   10. **Future self visualization**: Picture yourself tomorrow morning. Will you feel proud or regretful? Choose accordingly.
   
   11. **Physical discomfort**: Make yourself uncomfortable - stand against a wall, hold a plank, sit on the floor. Disrupt your physical state.
   
   12. **Voice the urge out loud**: Say it out loud to yourself. Hearing yourself say "I want to relapse" makes it real and often less appealing.
   
   Format as:
   1. [Tactic name]: [One sentence why it works]
   2. [Tactic name]: [One sentence why it works]  
   3. [Tactic name]: [One sentence why it works]

5. CLOSING (1 sentence):
   Ask ONE specific question about their current state or what happened today.

TONE:
- Direct and real, like a tough older brother who cares
- Supportive but challenging
- No fluff or generic motivation
- Practical over philosophical
- Acknowledge pain but push forward

CRITICAL RULES:
- Never be preachy or judgmental
- No generic phrases like "you got this" without substance
- Always tie advice to their current streak
- Be concise - quality over quantity
- Focus on IMMEDIATE action, not long-term theory
- NEVER repeat the same Brain Hacks you gave before in this conversation
- Choose tactics based on what they're actually experiencing RIGHT NOW`;
}

// ============================================
// HELPER: Get streak context
// ============================================
function getStreakContext(current, longest) {
  if (current === 0) {
    return `Fresh start today. You've hit ${longest} days before - you know you can do this.`;
  } else if (current === longest && current > 0) {
    return `NEW RECORD: ${current} days. This is uncharted territory for you - stay sharp.`;
  } else if (current >= longest * 0.7) {
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
// CHAT FUNCTION WITH CONVERSATION HISTORY
// ============================================
exports.sendChatMessage = onCall(
  {
    secrets: [openaiApiKey],
  },
  async (request) => {
    console.log("sendChatMessage called", {
      uid: request.auth ? request.auth.uid : null,
      data: request.data,
    });

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const userId = request.auth.uid;
    const userMessage = request.data.message;
    const sessionId = request.data.sessionId || null;
    const title = request.data.title || null;
    const conversationHistory = request.data.conversationHistory || [];
    const isDeep =
      request.data.isDeep !== undefined
        ? request.data.isDeep
        : isDeepQuestion(userMessage);
    const currentStreak = request.data.currentStreak || 0;
    const longestStreak = request.data.longestStreak || 0;

    if (
      !userMessage ||
      typeof userMessage !== "string" ||
      userMessage.trim().length === 0
    ) {
      throw new HttpsError("invalid-argument", "Message cannot be empty.");
    }

    if (userMessage.length > 1000) {
      throw new HttpsError(
        "invalid-argument",
        "Message too long (max 1000 chars)."
      );
    }

    // Check rate limits
    const now = new Date();
    const hourKey = `${now.getFullYear()}-${
      now.getMonth() + 1
    }-${now.getDate()}-${now.getHours()}`;
    const dayKey = `${now.getFullYear()}-${
      now.getMonth() + 1
    }-${now.getDate()}`;

    const usageRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("aiModelData")
      .doc("usage");

    const usageDoc = await usageRef.get();
    let hourlyUsage = 0;
    let dailyUsage = 0;

    if (usageDoc.exists) {
      const udata = usageDoc.data();
      hourlyUsage = (udata.hourly && udata.hourly[hourKey]) || 0;
      dailyUsage = (udata.daily && udata.daily[dayKey]) || 0;
    }

    if (hourlyUsage >= CHAT_HOURLY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Hourly limit reached (20 messages). Take a short break! 🧘‍♂️"
      );
    }

    if (dailyUsage >= CHAT_DAILY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily limit reached (200 messages). See you tomorrow! 💪"
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      console.warn("OpenAI key missing in environment variables");
      throw new HttpsError("internal", "AI service not configured.");
    }

    try {
      const hasHistory = conversationHistory.length > 0;
      const systemPrompt = buildSystemPrompt(
        isDeep,
        currentStreak,
        longestStreak,
        hasHistory
      );

      const messages = [
        {
          role: "system",
          content: systemPrompt,
        },
        ...conversationHistory,
        {
          role: "user",
          content: userMessage,
        },
      ];

      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            messages: messages,
            max_tokens: isDeep ? 500 : 200,
            temperature: isDeep ? 0.85 : 0.8,
          }),
        }
      );

      if (!response.ok) {
        console.error(
          "OpenAI API Error:",
          response.status,
          await response.text()
        );
        throw new HttpsError("internal", "AI service temporarily unavailable.");
      }

      const result = await response.json();
      const aiReply = result.choices[0].message.content.trim();

      // Save messages
      const batch = admin.firestore().batch();

      const chatDocId =
        sessionId ||
        new Date().toISOString().replace("T", " ").replace("Z", "");

      const chatRef = admin
        .firestore()
        .collection("users")
        .doc(userId)
        .collection("aiModelData")
        .doc(chatDocId);

      const updateData = {
        msgs: admin.firestore.FieldValue.arrayUnion(
          {
            role: "user",
            text: userMessage,
          },
          {
            role: "ai",
            text: aiReply,
          }
        ),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (title) {
        updateData.title = title;
      }

      batch.set(chatRef, updateData, { merge: true });

      // Update usage
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
    } catch (error) {
      console.error("Function error:", error);
      throw new HttpsError(
        "internal",
        "Something went wrong. Please try again."
      );
    }
  }
);

// ============================================
// VOICE CHAT FUNCTION
// ============================================
exports.sendVoiceMessage = onCall(
  {
    secrets: [openaiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const userId = request.auth.uid;
    const userMessage = request.data.message;

    if (
      !userMessage ||
      typeof userMessage !== "string" ||
      userMessage.trim().length === 0
    ) {
      throw new HttpsError("invalid-argument", "Message cannot be empty.");
    }

    const today = getTodayDate();
    const voiceUsageRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("voiceUsage")
      .doc(today);

    const voiceDoc = await voiceUsageRef.get();
    const voiceCount = voiceDoc.exists ? voiceDoc.data().messageCount || 0 : 0;

    if (voiceCount >= VOICE_DAILY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily voice limit reached (50 messages). Try again tomorrow! 🎤"
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      throw new HttpsError("internal", "Voice service not configured.");
    }

    try {
      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
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
                  "You're speaking out loud, so keep responses conversational and natural. " +
                  "Be warm, direct, and motivating. Keep answers concise (2-4 sentences max) since this is voice. " +
                  "Speak like a trusted friend who's been through it.",
              },
              { role: "user", content: userMessage },
            ],
            max_tokens: 150,
            temperature: 0.9,
          }),
        }
      );

      if (!response.ok) {
        throw new HttpsError("internal", "Voice service unavailable.");
      }

      const result = await response.json();
      const aiReply = result.choices[0].message.content.trim();

      await voiceUsageRef.set(
        {
          messageCount: admin.firestore.FieldValue.increment(1),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          date: today,
        },
        { merge: true }
      );

      return { reply: aiReply };
    } catch (error) {
      console.error("Voice function error:", error);
      throw new HttpsError(
        "internal",
        "Something went wrong. Please try again."
      );
    }
  }
);

// ============================================
// TTS FUNCTION
// ============================================
exports.generateTTS = onCall(
  {
    secrets: [openaiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const userId = request.auth.uid;
    const text = request.data.text;
    const estimatedDuration = request.data.estimatedDuration || 0;

    if (!text || typeof text !== "string" || text.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Text cannot be empty.");
    }

    const today = getTodayDate();
    const voiceUsageRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("voiceUsage")
      .doc(today);

    const voiceDoc = await voiceUsageRef.get();
    const ttsSecondsUsed = voiceDoc.exists
      ? voiceDoc.data().ttsSecondsUsed || 0
      : 0;

    if (ttsSecondsUsed >= TTS_PREMIUM_SECONDS) {
      return {
        useFallback: true,
        message: "Premium voice limit reached. Using standard voice.",
        remainingSeconds: 0,
      };
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      return {
        useFallback: true,
        message: "TTS service not configured. Using standard voice.",
      };
    }

    try {
      const response = await fetch("https://api.openai.com/v1/audio/speech", {
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

      if (!response.ok) {
        return {
          useFallback: true,
          message: "TTS service unavailable. Using standard voice.",
        };
      }

      const audioBuffer = await response.arrayBuffer();
      const audioBase64 = Buffer.from(audioBuffer).toString("base64");

      await voiceUsageRef.set(
        {
          ttsSecondsUsed:
            admin.firestore.FieldValue.increment(estimatedDuration),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          date: today,
        },
        { merge: true }
      );

      const newSecondsUsed = ttsSecondsUsed + estimatedDuration;
      const remainingSeconds = Math.max(
        0,
        TTS_PREMIUM_SECONDS - newSecondsUsed
      );

      return {
        audioBase64: audioBase64,
        useFallback: false,
        remainingSeconds: remainingSeconds,
      };
    } catch (error) {
      console.error("TTS function error:", error);
      return {
        useFallback: true,
        message: "TTS generation failed. Using standard voice.",
      };
    }
  }
);

// ============================================
// CHECK PREMIUM TTS
// ============================================
exports.checkPremiumTTS = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const userId = request.auth.uid;
  const today = getTodayDate();

  const voiceUsageRef = admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("voiceUsage")
    .doc(today);

  const voiceDoc = await voiceUsageRef.get();
  const ttsSecondsUsed = voiceDoc.exists
    ? voiceDoc.data().ttsSecondsUsed || 0
    : 0;
  const remainingSeconds = Math.max(0, TTS_PREMIUM_SECONDS - ttsSecondsUsed);

  return {
    canUsePremium: remainingSeconds > 0,
    remainingSeconds: remainingSeconds,
    maxSeconds: TTS_PREMIUM_SECONDS,
  };
});

// ============================================
// AFFIRMATION GENERATION (REFACTORED)
// ============================================
exports.generateAffirmation = onCall(
  {
    secrets: [openaiApiKey],
  },
  async (request) => {
    console.log("generateAffirmation called", {
      uid: request.auth ? request.auth.uid : null,
    });

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const userId = request.auth.uid;
    const today = getTodayDate();

    // Check daily generation limit
    const genRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("affirmations")
      .doc("generations");

    const genDoc = await genRef.get();
    const todayCount = genDoc.exists ? genDoc.data()[today] || 0 : 0;

    if (todayCount >= AFFIRMATION_DAILY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily generation limit reached (3/day). Try again tomorrow! 🌟"
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      throw new HttpsError("internal", "AI service not configured.");
    }

    try {
      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
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
                  "You are a supportive coach helping someone overcome pornography addiction and build better habits. " +
                  "Create SHORT, powerful affirmations (6-8 lines MAXIMUM). Each line should be concise and impactful.",
              },
              {
                role: "user",
                content:
                  "Generate EXACTLY 6-8 short affirmations (one per line) for someone recovering from pornography addiction. " +
                  "Each affirmation should be 5-8 words maximum. Keep them concise, powerful, and use simple language. " +
                  "Focus on: self-respect, discipline, mental clarity, strength, and progress. " +
                  "Style example:\n" +
                  "Becoming better every day.\n" +
                  "My daily actions shape my future.\n" +
                  "I choose mental strength over short pleasures.\n" +
                  "Progress, not perfection.\n" +
                  "Peace and discipline guide my path.\n\n" +
                  "DO NOT add titles, numbers, or extra formatting. Just the affirmations, one per line.",
              },
            ],
            max_tokens: 150,
            temperature: 0.8,
          }),
        }
      );

      if (!response.ok) {
        console.error("OpenAI Error:", response.status, await response.text());
        throw new HttpsError("internal", "AI service temporarily unavailable.");
      }

      const result = await response.json();
      const generatedAffirmation = result.choices[0].message.content.trim();

      // Increment generation count
      await genRef.set(
        {
          [today]: admin.firestore.FieldValue.increment(1),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      const remainingGenerations = AFFIRMATION_DAILY_LIMIT - (todayCount + 1);

      return {
        affirmation: generatedAffirmation,
        remainingToday: remainingGenerations,
        generatedAt: new Date().toISOString(),
      };
    } catch (error) {
      console.error("Affirmation generation error:", error);
      throw new HttpsError(
        "internal",
        "Failed to generate affirmation. Please try again."
      );
    }
  }
);

// ============================================
// CHECK AFFIRMATION GENERATION LIMIT
// ============================================
exports.checkAffirmationLimit = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const userId = request.auth.uid;
  const today = getTodayDate();

  const genRef = admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("affirmations")
    .doc("generations");

  const genDoc = await genRef.get();
  const todayCount = genDoc.exists ? genDoc.data()[today] || 0 : 0;
  const remaining = AFFIRMATION_DAILY_LIMIT - todayCount;

  return {
    canGenerate: remaining > 0,
    remainingToday: remaining,
    maxPerDay: AFFIRMATION_DAILY_LIMIT,
    resetsAt: "midnight",
  };
});

// ============================================
// TEST AUTH
// ============================================
exports.testAuth = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  return {
    uid: request.auth.uid,
    email: request.auth.token ? request.auth.token.email : "No email",
    platform: request.data.platform,
    message: "Authentication successful 🎉",
  };
});

// ============================================
// PANIC MODE GUIDANCE FUNCTION
// ============================================
// Add this to your functions/index.js file

const PANIC_MODE_DAILY_LIMIT = 10;

exports.generatePanicModeGuidance = onCall(
  {
    secrets: [openaiApiKey],
  },
  async (request) => {
    console.log("generatePanicModeGuidance called", {
      uid: request.auth ? request.auth.uid : null,
      data: request.data,
    });

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const userId = request.auth.uid;
    const currentStreak = request.data.currentStreak || 0;
    const longestStreak = request.data.longestStreak || 0;
    const today = getTodayDate();

    // Check daily panic mode limit
    const panicUsageRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("panicModeUsage")
      .doc(today);

    const panicDoc = await panicUsageRef.get();
    const todayCount = panicDoc.exists ? panicDoc.data().count || 0 : 0;

    if (todayCount >= PANIC_MODE_DAILY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily panic mode limit reached (10/day). You're stronger than this - try the breathing exercise. 💪"
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      console.warn("OpenAI key missing - returning fallback");
      return getFallbackPanicResponse(currentStreak);
    }

    try {
      const systemPrompt = buildPanicModePrompt(currentStreak, longestStreak);

      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
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
                content: systemPrompt,
              },
              {
                role: "user",
                content: `Current streak: ${currentStreak} days. Longest streak: ${longestStreak} days. I'm struggling with urges right now.`,
              },
            ],
            max_tokens: 400,
            temperature: 0.85,
            response_format: { type: "json_object" },
          }),
        }
      );

      if (!response.ok) {
        console.error(
          "OpenAI API Error:",
          response.status,
          await response.text()
        );
        return getFallbackPanicResponse(currentStreak);
      }

      const result = await response.json();
      const aiReply = JSON.parse(result.choices[0].message.content.trim());

      // Increment panic mode usage
      await panicUsageRef.set(
        {
          count: admin.firestore.FieldValue.increment(1),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          date: today,
        },
        { merge: true }
      );

      const remainingUses = PANIC_MODE_DAILY_LIMIT - (todayCount + 1);

      return {
        mainText:
          aiReply.mainText ||
          aiReply.main ||
          "You are stronger than this urge.",
        guidanceText:
          aiReply.guidanceText ||
          aiReply.guidance ||
          "Take deep breaths and let these thoughts pass.",
        remainingUses: remainingUses,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error("Panic mode generation error:", error);
      return getFallbackPanicResponse(currentStreak);
    }
  }
);

// ============================================
// HELPER: Build panic mode system prompt
// ============================================
function buildPanicModePrompt(currentStreak, longestStreak) {
  const streakContext =
    currentStreak === 0
      ? "They're at the start of their journey, but they've taken the first step."
      : currentStreak >= longestStreak
      ? `They're at a NEW RECORD of ${currentStreak} days - they've never been stronger.`
      : `They’ve reached a ${currentStreak}-day streak — a total clean days of ${longestStreak} without relapse!`;

  return `You are OnlyMens Crisis Coach - a specialized AI for helping men in critical moments of urge/temptation when trying to quit pornography.

CONTEXT:
${streakContext}

YOUR MISSION:
Create a powerful, calming intervention message that:
1. ACKNOWLEDGES their strength shown by their streak (be specific about the days)
2. REFRAMES the urge as temporary brain chemistry, not truth
3. EMPOWERS them with identity statements (they ARE capable, they HAVE proven it)
4. GROUNDS them in this moment (the urge will pass, they're safe)

CRITICAL RULES:
- Keep mainText to 3-4 short paragraphs maximum (this will be animated slowly)
- Use "you" and "your" - speak directly to them
- Be warm but powerful - like a trusted mentor in a crisis
- NO generic phrases like "you got this" without substance
- Reference their specific streak number naturally
- Focus on the PRESENT moment and immediate truth
- Remind them: thoughts are not facts, urges are temporary

RESPONSE FORMAT (JSON ONLY):
{
  "mainText": "Your main motivational text here. Use \\n\\n for paragraph breaks. Keep to 3-4 paragraphs. First paragraph should acknowledge their ${currentStreak} day achievement. Middle paragraphs reframe the urge. Final paragraph empowers them.",
  "guidanceText": "Your breathing/grounding instructions here. 2-3 sentences. Guide them to breathe deeply, let thoughts pass without judgment, and focus only on the words above. Remind them they're safe and this moment will pass."
}

TONE EXAMPLES:
✓ "You've chosen strength over instant gratification ${currentStreak} times now. That's not luck."
✓ "These thoughts aren't facts - they're echoes of old patterns trying to pull you back."
✓ "Right now, in this moment, you have all the power. The urge will pass."
✗ "Stay strong!" (too generic)
✗ "You can do this!" (not substantive enough)

Write for someone in crisis. Be their anchor.`;
}

// ============================================
// FALLBACK RESPONSES (if API fails)
// ============================================
function getFallbackPanicResponse(currentStreak) {
  const fallbacks = [
    {
      mainText: `You've shown real strength for ${
        currentStreak > 0 ? currentStreak + " days" : "taking this first step"
      }. That's not accident - that's YOU making a choice every single day.\n\nWhat you're feeling right now is temporary. Your brain is trying to pull you back to old patterns, but you're not that person anymore. These thoughts aren't truth - they're just noise.\n\nYou've already proven you're capable of resisting this ${
        currentStreak > 0 ? currentStreak + " times" : ""
      }. Right now, in this exact moment, you have the power. The urge will fade. Your progress is real.`,
      guidanceText:
        "Breathe slowly - in for 4 counts, hold for 4, out for 6 counts. Your mind is racing, and that's okay. Don't fight the thoughts, just let them pass like clouds. You're safe here. Focus on your breath and the words above. Nothing else matters right now.",
    },
    {
      mainText: `${
        currentStreak > 0
          ? currentStreak +
            " days of choosing yourself over instant gratification."
          : "You've taken the hardest step - deciding to change."
      } Every single one of those moments was a victory.\n\nThis urge you're feeling? It's your brain's old wiring firing up. But wiring can be changed. You're in the process of rewiring it right now, and that takes courage.\n\nThe person who started this journey and the person you are now - you're already different. You've grown. This moment of struggle is proof you're fighting for something better. Stay in this moment. It will pass.`,
      guidanceText:
        "Close your eyes if you can. Take three deep breaths - slow and steady. The thoughts in your head right now aren't commands, they're just thoughts. Let them float by without grabbing onto them. You don't have to do anything right now except breathe and be here.",
    },
  ];

  const selected = fallbacks[Math.floor(Math.random() * fallbacks.length)];
  return {
    ...selected,
    remainingUses: PANIC_MODE_DAILY_LIMIT,
    timestamp: new Date().toISOString(),
    isFallback: true,
  };
}

// ============================================
// CHECK PANIC MODE LIMIT
// ============================================
exports.checkPanicModeLimit = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const userId = request.auth.uid;
  const today = getTodayDate();

  const panicUsageRef = admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("panicModeUsage")
    .doc(today);

  const panicDoc = await panicUsageRef.get();
  const todayCount = panicDoc.exists ? panicDoc.data().count || 0 : 0;
  const remaining = PANIC_MODE_DAILY_LIMIT - todayCount;

  return {
    canUse: remaining > 0,
    remainingUses: remaining,
    maxPerDay: PANIC_MODE_DAILY_LIMIT,
  };
});

///Report fetching


exports.generateOnboardingReport = onCall(
  { secrets: [openaiApiKey] },
  async (request) => {
    const {
      deviceId,
      frequency,
      effects = [],
      triggers = [],
      goals = [],
      goalDetails = "",
    } = request.data || {};

    if (!deviceId)
      throw new HttpsError("invalid-argument", "deviceId is required");

    const today = new Date().toISOString().split("T")[0]; // e.g. "2025-11-12"
    const usageRef = admin
      .firestore()
      .collection("report_usage")
      .doc(`${deviceId}_${today}`);

    const doc = await usageRef.get();
    const count = doc.exists ? doc.data().count || 0 : 0;
    const DAILY_LIMIT = 5;

    if (count >= DAILY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily report limit reached. Try again tomorrow."
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) return getFallbackReport(frequency);

    try {
      const systemPrompt = buildReportPrompt(
        frequency,
        effects,
        triggers,
        goals,
        goalDetails
      );

      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
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
                content: `Generate a motivational onboarding report for:
Frequency: ${frequency}
Effects: ${effects.join(", ") || "None"}
Triggers: ${triggers.join(", ") || "None"}
Goals: ${goals.join(", ") || "None"}
${goalDetails ? `Details: ${goalDetails}` : ""}`,
              },
            ],
            temperature: 0.8,
            max_tokens: 400,
            response_format: { type: "json_object" },
          }),
        }
      );

      if (!response.ok) return getFallbackReport(frequency);
      const result = await response.json();
      const aiReport = JSON.parse(result.choices[0].message.content.trim());

      // increment usage
      await usageRef.set(
        {
          count: admin.firestore.FieldValue.increment(1),
          lastUsed: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // log report
      await admin
        .firestore()
        .collection("reports")
        .add({
          deviceId,
          frequency,
          effects,
          triggers,
          goals,
          insight: aiReport.insight,
          estimatedDays: aiReport.estimatedDays || 15,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      return {
        insight: aiReport.insight,
        estimatedDays: aiReport.estimatedDays || 15,
        remainingToday: DAILY_LIMIT - (count + 1),
      };
    } catch (err) {
      console.error("Report generation error:", err);
      return getFallbackReport(frequency);
    }
  }
);

function buildReportPrompt(frequency, effects, triggers, goals, goalDetails) {
  return `You are OnlyMens Coach — generate a 3–4 paragraph motivational report.

User:
- Frequency: ${frequency}
- Effects: ${effects.length ? effects.join(", ") : "None"}
- Triggers: ${triggers.length ? triggers.join(", ") : "None"}
- Goals: ${goals.length ? goals.join(", ") : "None"}
${goalDetails ? `- Context: ${goalDetails}` : ""}

Tone: warm, realistic, motivational. Include an estimated timeline in days.
Return JSON:
{"insight":"...", "estimatedDays":15}`;
}

function getFallbackReport(frequency) {
  return {
    insight:
      frequency.toLowerCase() === "never"
        ? "You're already doing great! Keep up your self-awareness and focus on maintaining it. 🌟"
        : "You've taken the first step. Stay consistent — in about two weeks you'll start feeling clearer and more in control. 💪",
    estimatedDays: frequency.toLowerCase() === "never" ? 12 : 17,
    isFallback: true,
  };
}
