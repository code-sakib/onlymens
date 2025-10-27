const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// ============================================
// RATE LIMITS
// ============================================
const CHAT_HOURLY_LIMIT = 20;
const CHAT_DAILY_LIMIT = 200;
const VOICE_DAILY_LIMIT = 50; // Voice messages per day
const TTS_PREMIUM_SECONDS = 180; // 3 minutes of premium TTS per day

// ============================================
// CHAT FUNCTION
// ============================================
exports.sendChatMessage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const userId = context.auth.uid;
  const userMessage = data.message;

  if (!userMessage || typeof userMessage !== 'string' || userMessage.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Message cannot be empty.');
  }

  if (userMessage.length > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'Message too long (max 1000 chars).');
  }

  // Check rate limits
  const now = new Date();
  const hourKey = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}-${now.getHours()}`;
  const dayKey = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;

  const usageRef = admin.firestore()
    .collection('users')
    .doc(userId)
    .collection('aiModelData')
    .doc('usage');

  const usageDoc = await usageRef.get();
  let hourlyUsage = 0;
  let dailyUsage = 0;

  if (usageDoc.exists) {
    const data = usageDoc.data();
    hourlyUsage = (data.hourly && data.hourly[hourKey]) || 0;
    dailyUsage = (data.daily && data.daily[dayKey]) || 0;
  }

  if (hourlyUsage >= CHAT_HOURLY_LIMIT) {
    throw new functions.https.HttpsError('resource-exhausted', 
      'Hourly limit reached (20 messages). Take a short break! 🧘‍♂️');
  }

  if (dailyUsage >= CHAT_DAILY_LIMIT) {
    throw new functions.https.HttpsError('resource-exhausted', 
      'Daily limit reached (200 messages). See you tomorrow! 💪');
  }

  // Call OpenAI Chat API
  const openaiApiKey = functions.config().openai.key;

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: "You are OnlyMens, a supportive AI that helps men quit pornography addiction. " +
                    "You are kind, practical, and motivating. " +
                    "Avoid judging the user. Help him identify triggers, plan short streaks, and stay positive."
          },
          { role: 'user', content: userMessage }
        ],
        max_tokens: 250,
        temperature: 0.8
      })
    });

    if (!response.ok) {
      console.error('OpenAI API Error:', response.status, await response.text());
      throw new functions.https.HttpsError('internal', 'AI service temporarily unavailable.');
    }

    const result = await response.json();
    const aiReply = result.choices[0].message.content.trim();

    // Save messages and update usage
    const batch = admin.firestore().batch();
    const messagesRef = admin.firestore().collection('users').doc(userId).collection('aiModelData');

    batch.set(messagesRef.doc(), {
      role: 'user',
      content: userMessage,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    batch.set(messagesRef.doc(), {
      role: 'assistant',
      content: aiReply,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    batch.set(usageRef, {
      [`hourly.${hourKey}`]: admin.firestore.FieldValue.increment(1),
      [`daily.${dayKey}`]: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    await batch.commit();

    return { reply: aiReply };

  } catch (error) {
    console.error('Function error:', error);
    throw new functions.https.HttpsError('internal', 'Something went wrong. Please try again.');
  }
});

// ============================================
// VOICE CHAT FUNCTION
// ============================================
exports.sendVoiceMessage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const userId = context.auth.uid;
  const userMessage = data.message;

  if (!userMessage || typeof userMessage !== 'string' || userMessage.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Message cannot be empty.');
  }

  // Check daily voice limit
  const today = getTodayDate();
  const voiceUsageRef = admin.firestore()
    .collection('users')
    .doc(userId)
    .collection('voiceUsage')
    .doc(today);

  const voiceDoc = await voiceUsageRef.get();
  const voiceCount = voiceDoc.exists ? (voiceDoc.data().messageCount || 0) : 0;

  if (voiceCount >= VOICE_DAILY_LIMIT) {
    throw new functions.https.HttpsError('resource-exhausted', 
      'Daily voice limit reached (50 messages). Try again tomorrow! 🎤');
  }

  // Call OpenAI Chat API (optimized for voice)
  const openaiApiKey = functions.config().openai.key;

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: "You are OnlyMens Voice Coach, a supportive AI companion for men overcoming pornography addiction. " +
                    "You're speaking out loud, so keep responses conversational and natural. " +
                    "Be warm, direct, and motivating. Keep answers concise (2-4 sentences max) since this is voice. " +
                    "Speak like a trusted friend who's been through it. " +
                    "Use simple language, short sentences, and natural pauses. " +
                    "Avoid lists or complex formatting - just talk naturally."
          },
          { role: 'user', content: userMessage }
        ],
        max_tokens: 150,
        temperature: 0.9
      })
    });

    if (!response.ok) {
      console.error('OpenAI Voice API Error:', response.status, await response.text());
      throw new functions.https.HttpsError('internal', 'Voice service unavailable.');
    }

    const result = await response.json();
    const aiReply = result.choices[0].message.content.trim();

    // Update voice usage
    await voiceUsageRef.set({
      messageCount: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      date: today
    }, { merge: true });

    return { reply: aiReply };

  } catch (error) {
    console.error('Voice function error:', error);
    throw new functions.https.HttpsError('internal', 'Something went wrong. Please try again.');
  }
});

// ============================================
// TTS (TEXT-TO-SPEECH) FUNCTION
// ============================================
exports.generateTTS = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const userId = context.auth.uid;
  const text = data.text;
  const estimatedDuration = data.estimatedDuration || 0;

  if (!text || typeof text !== 'string' || text.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Text cannot be empty.');
  }

  // Check premium TTS usage
  const today = getTodayDate();
  const voiceUsageRef = admin.firestore()
    .collection('users')
    .doc(userId)
    .collection('voiceUsage')
    .doc(today);

  const voiceDoc = await voiceUsageRef.get();
  const ttsSecondsUsed = voiceDoc.exists ? (voiceDoc.data().ttsSecondsUsed || 0) : 0;

  if (ttsSecondsUsed >= TTS_PREMIUM_SECONDS) {
    // Exceeded premium limit - tell client to use Flutter TTS
    return { 
      useFallback: true,
      message: 'Premium voice limit reached. Using standard voice.',
      remainingSeconds: 0
    };
  }

  // Call OpenAI TTS API
  const openaiApiKey = functions.config().openai.key;

  try {
    const response = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`
      },
      body: JSON.stringify({
        model: 'tts-1',
        voice: 'fable',
        input: text,
        speed: 1.0
      })
    });

    if (!response.ok) {
      console.error('OpenAI TTS Error:', response.status, await response.text());
      return { 
        useFallback: true,
        message: 'TTS service unavailable. Using standard voice.'
      };
    }

    // Get audio as base64
    const audioBuffer = await response.arrayBuffer();
    const audioBase64 = Buffer.from(audioBuffer).toString('base64');

    // Update TTS usage
    await voiceUsageRef.set({
      ttsSecondsUsed: admin.firestore.FieldValue.increment(estimatedDuration),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      date: today
    }, { merge: true });

    const newSecondsUsed = ttsSecondsUsed + estimatedDuration;
    const remainingSeconds = Math.max(0, TTS_PREMIUM_SECONDS - newSecondsUsed);

    return { 
      audioBase64: audioBase64,
      useFallback: false,
      remainingSeconds: remainingSeconds
    };

  } catch (error) {
    console.error('TTS function error:', error);
    return { 
      useFallback: true,
      message: 'TTS generation failed. Using standard voice.'
    };
  }
});

// ============================================
// CHECK PREMIUM TTS AVAILABILITY
// ============================================
exports.checkPremiumTTS = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const userId = context.auth.uid;
  const today = getTodayDate();

  const voiceUsageRef = admin.firestore()
    .collection('users')
    .doc(userId)
    .collection('voiceUsage')
    .doc(today);

  const voiceDoc = await voiceUsageRef.get();
  const ttsSecondsUsed = voiceDoc.exists ? (voiceDoc.data().ttsSecondsUsed || 0) : 0;
  const remainingSeconds = Math.max(0, TTS_PREMIUM_SECONDS - ttsSecondsUsed);

  return {
    canUsePremium: remainingSeconds > 0,
    remainingSeconds: remainingSeconds,
    maxSeconds: TTS_PREMIUM_SECONDS
  };
});

// ============================================
// HELPER FUNCTION
// ============================================
function getTodayDate() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}