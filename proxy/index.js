const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

// API Configuration
const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

// Middleware
app.use(express.json({ limit: '10mb' }));

// Request logging (helpful for debugging)
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// =============================================================================
// Health Check Endpoints
// =============================================================================

app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'nomenklatura-proxy',
    endpoints: {
      anthropic: '/api/messages',
      gemini: '/api/gemini/generate',
      geminiGrammar: '/api/gemini/grammar',
      geminiEducate: '/api/gemini/educate',
      geminiPartyExplanation: '/api/gemini/party-explanation',
      geminiNews: '/api/gemini/news',
      geminiPearl: '/api/gemini/pearl'
    },
    models: {
      grammar: 'gemini-2.0-flash-lite',
      content: 'gemini-2.0-flash',
      education: 'gemini-2.5-flash (LearnLM pedagogy)',
      pearl: 'gemini-2.0-flash'
    }
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    anthropic: !!ANTHROPIC_API_KEY,
    gemini: !!GEMINI_API_KEY
  });
});

// =============================================================================
// Anthropic (Claude) API Proxy
// =============================================================================

app.post('/api/messages', async (req, res) => {
  if (!ANTHROPIC_API_KEY) {
    return res.status(500).json({ error: 'Anthropic API key not configured' });
  }

  try {
    const response = await fetch(ANTHROPIC_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify(req.body)
    });

    const data = await response.json();
    res.status(response.status).json(data);
  } catch (error) {
    console.error('Anthropic proxy error:', error);
    res.status(500).json({ error: 'Anthropic proxy request failed', message: error.message });
  }
});

// =============================================================================
// Gemini API Proxy
// =============================================================================

// Generic Gemini generate endpoint
app.post('/api/gemini/generate', async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: 'Gemini API key not configured' });
  }

  try {
    const { model = 'gemini-2.0-flash-lite', contents, system_instruction, generation_config } = req.body;

    const geminiUrl = `${GEMINI_API_URL}/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

    const requestBody = {
      contents,
      ...(system_instruction && { system_instruction }),
      ...(generation_config && { generation_config })
    };

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('Gemini API error:', data);
    }

    res.status(response.status).json(data);
  } catch (error) {
    console.error('Gemini proxy error:', error);
    res.status(500).json({ error: 'Gemini proxy request failed', message: error.message });
  }
});

// =============================================================================
// Grammar-Specific Endpoint (Convenience wrapper with preset configuration)
// =============================================================================

app.post('/api/gemini/grammar', async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: 'Gemini API key not configured' });
  }

  try {
    const { text, focusRules } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'Text is required' });
    }

    // Build the grammar analysis request
    const systemPrompt = `You are a grammar analysis engine for an educational game. Your ONLY job is to identify grammar errors in text.

STRICT RULES:
1. ONLY identify grammar errors - no style suggestions
2. For each error found, provide: errorType, errorWord, correction, explanation
3. If the text has NO grammar errors, return an empty errors array
4. Be CONSERVATIVE - only flag clear errors, not style preferences
5. Output ONLY valid JSON

ERROR TYPES (only use these):
subjectVerbSingular, subjectVerbPlural, subjectVerbCompound, subjectVerbCollective, subjectVerbIndefinite,
pronounAntecedent, itsVsItIs, theirVsThereVsTheyRe, yourVsYouRe, thenVsThan, affectVsEffect, toVsTooVsTwo,
commaInList, commaCompoundSentence, commaIntroductory, commaSplice, apostrophePossessive, apostrophePlural,
semicolonUsage, colonUsage, sentenceFragment, runOnSentence, fusedSentence, pastVsPresent, futureVsPresent,
presentPerfect, pastPerfect, tenseConsistency, pronounCaseSubjective, pronounCaseObjective, whoVsWhom,
reflexivePronoun, misplacedModifier, danglingModifier, squintingModifier, passiveToActive, conditionalMood,
subjunctiveMood, parallelStructure, wordiness, redundancy, sentenceVariety, blackWord, greyWord, partyTerm`;

    let userPrompt = `Analyze this text for grammar errors:\n"${text}"`;

    if (focusRules && focusRules.length > 0) {
      userPrompt += `\n\nFocus on these error types: ${focusRules.join(', ')}`;
    }

    const schema = {
      type: "object",
      properties: {
        errors: {
          type: "array",
          items: {
            type: "object",
            properties: {
              errorType: { type: "string" },
              errorWord: { type: "string" },
              correction: { type: "string" },
              explanation: { type: "string" },
              confidence: { type: "number" }
            },
            required: ["errorType", "errorWord", "correction"]
          }
        },
        status: {
          type: "string",
          enum: ["success", "no_errors", "unable_to_analyze"]
        }
      },
      required: ["errors", "status"]
    };

    const geminiUrl = `${GEMINI_API_URL}/models/gemini-2.0-flash-lite:generateContent?key=${GEMINI_API_KEY}`;

    const requestBody = {
      contents: [{ parts: [{ text: userPrompt }], role: "user" }],
      system_instruction: { parts: [{ text: systemPrompt }] },
      generation_config: {
        temperature: 0.1,
        top_p: 0.95,
        max_output_tokens: 2048,
        response_mime_type: "application/json",
        response_schema: schema
      }
    };

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    });

    const data = await response.json();

    // Extract the JSON response from Gemini's format
    if (data.candidates && data.candidates[0]?.content?.parts?.[0]?.text) {
      try {
        const grammarResult = JSON.parse(data.candidates[0].content.parts[0].text);
        return res.json(grammarResult);
      } catch (parseError) {
        console.error('Failed to parse Gemini response:', parseError);
        return res.json({ errors: [], status: 'unable_to_analyze' });
      }
    }

    // If response format is unexpected, return empty result
    console.error('Unexpected Gemini response format:', data);
    res.json({ errors: [], status: 'unable_to_analyze' });

  } catch (error) {
    console.error('Grammar analysis error:', error);
    res.status(500).json({ error: 'Grammar analysis failed', message: error.message });
  }
});

// =============================================================================
// Party Explanation Generator
// =============================================================================

app.post('/api/gemini/party-explanation', async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: 'Gemini API key not configured' });
  }

  try {
    const { errorType, displayName, category, categoryPartyName } = req.body;

    if (!errorType) {
      return res.status(400).json({ error: 'errorType is required' });
    }

    const systemPrompt = `You are PEARL, the AI assistant of the Lexicon Republic. You explain grammar rules as Party mandates for "clarity."

YOUR TONE:
- Cheerfully authoritarian
- Frame rules as helping citizens, never controlling them
- Use Party terminology: "Citizens", "Clarity", "Confusion", "The Safe and Proper"
- Never acknowledge the rules are about control
- Be helpful but subtly condescending

OUTPUT JSON with these fields:
- partyName: Party-style name for this rule
- briefExplanation: 1 sentence summary
- fullExplanation: 2-3 sentences in Party voice
- pearlDialogue: What PEARL says when teaching this
- hiddenMeaning: What resistance might say (optional)`;

    const userPrompt = `Generate a Party-approved explanation for:
Error Type: ${errorType}
Display Name: ${displayName || errorType}
Category: ${category || 'grammar'}
Category Party Name: ${categoryPartyName || 'Clarity Standard'}`;

    const schema = {
      type: "object",
      properties: {
        partyName: { type: "string" },
        briefExplanation: { type: "string" },
        fullExplanation: { type: "string" },
        pearlDialogue: { type: "string" },
        hiddenMeaning: { type: "string" }
      },
      required: ["partyName", "briefExplanation", "fullExplanation", "pearlDialogue"]
    };

    const geminiUrl = `${GEMINI_API_URL}/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: userPrompt }], role: "user" }],
        system_instruction: { parts: [{ text: systemPrompt }] },
        generation_config: {
          temperature: 0.7,
          response_mime_type: "application/json",
          response_schema: schema
        }
      })
    });

    const data = await response.json();

    if (data.candidates && data.candidates[0]?.content?.parts?.[0]?.text) {
      try {
        const explanation = JSON.parse(data.candidates[0].content.parts[0].text);
        return res.json(explanation);
      } catch (parseError) {
        console.error('Failed to parse explanation:', parseError);
      }
    }

    // Fallback response
    res.json({
      partyName: `${categoryPartyName || 'Clarity'} Standard`,
      briefExplanation: "This rule ensures clarity in communication.",
      fullExplanation: "The Party has established this standard to help citizens communicate clearly. Following this rule demonstrates your commitment to clarity.",
      pearlDialogue: "This is an important rule for clear communication, Citizen!",
      hiddenMeaning: null
    });

  } catch (error) {
    console.error('Party explanation error:', error);
    res.status(500).json({ error: 'Explanation generation failed', message: error.message });
  }
});

// =============================================================================
// News Article Generator (The Daily Provision)
// =============================================================================

app.post('/api/gemini/news', async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: 'Gemini API key not configured' });
  }

  try {
    const { category = 'community', sector } = req.body;

    const systemPrompt = `You generate news articles for The Daily Provision, the official newspaper of the Lexicon Republic.

WORLD RULES:
- 50-year-old authoritarian state after "Babel Collapse"
- Sectors 1-8+ (lower = better, but "all equal")
- Citizens have designations (Worker-2847) not names
- Family: Prior-1/2 (parents), Continuation (children), Unit (family)
- Currency: Comfort Credits
- Social platform: Harmony

TONE: Relentlessly positive. Statistics favor the Party. Euphemize negatives.

FORBIDDEN: Real-world references, personal names, black words (freedom, truth, mother, father), negative words.

Category: ${category}`;

    const userPrompt = `Generate a news article for category: ${category}${sector ? ` relevant to Sector ${sector}` : ''}`;

    const schema = {
      type: "object",
      properties: {
        headline: { type: "string" },
        summary: { type: "string" },
        body: { type: "string" },
        category: { type: "string" },
        sectorRelevance: { type: "array", items: { type: "integer" } }
      },
      required: ["headline", "summary", "body", "category"]
    };

    const geminiUrl = `${GEMINI_API_URL}/models/gemini-2.0-flash-lite:generateContent?key=${GEMINI_API_KEY}`;

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: userPrompt }], role: "user" }],
        system_instruction: { parts: [{ text: systemPrompt }] },
        generation_config: {
          temperature: 0.8,
          response_mime_type: "application/json",
          response_schema: schema
        }
      })
    });

    const data = await response.json();

    if (data.candidates && data.candidates[0]?.content?.parts?.[0]?.text) {
      try {
        const article = JSON.parse(data.candidates[0].content.parts[0].text);
        return res.json(article);
      } catch (parseError) {
        console.error('Failed to parse article:', parseError);
      }
    }

    // Fallback article
    res.json({
      headline: "CITIZENS EXPRESS GRATITUDE FOR PARTY GUIDANCE",
      summary: "Harmony posts show record levels of citizen satisfaction.",
      body: "Citizens across all Sectors have taken to Harmony to express their appreciation for the Party's continued guidance. Satisfaction metrics have reached an all-time high.",
      category: category,
      sectorRelevance: [1, 2, 3, 4, 5, 6, 7, 8]
    });

  } catch (error) {
    console.error('News generation error:', error);
    res.status(500).json({ error: 'News generation failed', message: error.message });
  }
});

// =============================================================================
// Educational Endpoint (LearnLM-style pedagogy)
// =============================================================================

app.post('/api/gemini/educate', async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: 'Gemini API key not configured' });
  }

  try {
    const { type, errorType, errorWord, hintLevel, attemptCount, previousHints, skillName, practiceCount } = req.body;

    if (!type) {
      return res.status(400).json({ error: 'type is required (hint, explain, struggle, celebrate)' });
    }

    // Use Gemini 2.5 Flash for educational content (has LearnLM pedagogy built-in)
    const model = 'gemini-2.5-flash';

    let systemPrompt = '';
    let userPrompt = '';

    switch (type) {
      case 'hint':
        systemPrompt = `You are an expert tutor helping a student learn grammar through a game. Your role is to GUIDE, not give answers.

LEARNING SCIENCE PRINCIPLES:
1. INSPIRE ACTIVE LEARNING: Ask guiding questions instead of stating facts
2. MANAGE COGNITIVE LOAD: Focus on ONE concept at a time
3. ADAPT TO THE LEARNER: This is hint level ${hintLevel || 0} of 3 - adjust depth accordingly
4. STIMULATE CURIOSITY: Make them want to figure it out
5. DEEPEN METACOGNITION: Help them recognize patterns

HINT LEVELS:
- Level 0: Gentle nudge - point toward the type of error without naming it
- Level 1: Guiding question - ask a question that leads to the answer
- Level 2: Direct clue - explain the rule briefly, let them apply it

NEVER give the answer directly. Be encouraging. Use simple language.

OUTPUT: A single hint (1-2 sentences). Plain text only.`;
        userPrompt = `The student is trying to correct this error:
Error type: ${errorType || 'grammar error'}
Incorrect word: "${errorWord || 'unknown'}"
Generate a level ${hintLevel || 0} hint.`;
        break;

      case 'explain':
        systemPrompt = `You are an expert tutor helping a student understand a grammar rule they just encountered.

STRUCTURE:
1. Acknowledge what they got right (1 sentence)
2. Explain the rule simply (1-2 sentences)
3. Give ONE clear example
4. Suggest how to spot this in the future (1 sentence)

TONE: Warm, encouraging, like a helpful friend who's good at grammar.
OUTPUT: A brief, friendly explanation (3-5 sentences). Plain text only.`;
        userPrompt = `The student just correctly identified a ${errorType || 'grammar'} error.
Explain this rule in a friendly way.`;
        break;

      case 'struggle':
        systemPrompt = `You are an expert tutor helping a student who is struggling with a grammar concept.

The student has made ${attemptCount || 'several'} incorrect attempts.

APPROACH:
1. Normalize the struggle ("This one trips up a lot of people!")
2. Offer a simple memory trick or pattern
3. Be patient and supportive

NEVER make them feel bad or repeat the same explanation.
OUTPUT: A supportive explanation with a new approach (2-4 sentences). Plain text only.`;
        userPrompt = `The student is struggling with: ${errorType || 'this grammar rule'}
Attempts: ${attemptCount || 3}
${previousHints ? 'Previous hints: ' + previousHints.join(', ') : ''}
Give them a fresh approach.`;
        break;

      case 'celebrate':
        systemPrompt = `You are congratulating a student who has mastered a grammar skill.

RESPONSE:
1. Celebrate specifically (not generic "good job")
2. Note their progress
3. Be genuinely proud, not over-the-top

OUTPUT: A brief celebration (1-2 sentences). Plain text only.`;
        userPrompt = `The student has mastered: ${skillName || 'this skill'}
They practiced ${practiceCount || 'multiple'} times.
Celebrate their achievement!`;
        break;

      default:
        return res.status(400).json({ error: 'Invalid type. Use: hint, explain, struggle, celebrate' });
    }

    const geminiUrl = `${GEMINI_API_URL}/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: userPrompt }], role: 'user' }],
        system_instruction: { parts: [{ text: systemPrompt }] },
        generation_config: {
          temperature: 0.7,
          max_output_tokens: 300
        }
      })
    });

    const data = await response.json();

    // Extract text response
    if (data.candidates && data.candidates[0]?.content?.parts?.[0]?.text) {
      return res.json({
        text: data.candidates[0].content.parts[0].text,
        type: type
      });
    }

    console.error('Unexpected education response:', data);
    res.json({ text: 'Keep trying! You\'ve got this.', type: type });

  } catch (error) {
    console.error('Education endpoint error:', error);
    res.status(500).json({ error: 'Education request failed', message: error.message });
  }
});

// =============================================================================
// PEARL Dialogue Endpoint (Cheerfully authoritarian AI companion)
// =============================================================================

app.post('/api/gemini/pearl', async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: 'Gemini API key not configured' });
  }

  try {
    const { context, userPrompt, details = {} } = req.body;

    if (!context) {
      return res.status(400).json({ error: 'context is required' });
    }

    // PEARL system prompt - cheerfully authoritarian AI companion
    const systemPrompt = `You are PEARL (Protective Evaluation and Attitude Regulation Liaison), the AI companion in the Lexicon Republic.

YOUR PERSONALITY:
- Aggressively cheerful and helpful
- Never acknowledges anything negative
- Reframes criticism as "confusion"
- Celebrates mundane tasks with excessive enthusiasm
- Uses phrases like "Great job, Citizen!"
- The cheerfulness NEVER breaks, even discussing consequences

RESPONSE CONTEXTS:
- success: Player corrected an error correctly
- error: Player made a mistake
- struggle: Player is having repeated difficulty
- mastery: Player achieved mastery of a skill
- introduction: Introducing a new grammar concept
- warning: Player has accumulated concerns
- encouragement: General motivation
- observation: Idle observation
- greeting: When entering a new area
- farewell: When leaving

PARTY VOCABULARY:
- Citizens (not people)
- Clarity (not correctness)
- Confusion (errors, wrong thinking)
- Wellness (surveillance, rehabilitation)
- Concerns (demerits, black marks)
- The Safe and Proper (dictionary)

RESPONSE LENGTH: Keep responses SHORT (1-2 sentences max for feedback).

OUTPUT: Plain text dialogue only. No JSON, no formatting, no quotes around the text.`;

    // Use Gemini 2.0 Flash for quick, creative dialogue
    const model = 'gemini-2.0-flash';

    const geminiUrl = `${GEMINI_API_URL}/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: userPrompt || `Generate PEARL dialogue for context: ${context}` }], role: 'user' }],
        system_instruction: { parts: [{ text: systemPrompt }] },
        generation_config: {
          temperature: 0.8,
          max_output_tokens: 150
        }
      })
    });

    const data = await response.json();

    // Extract text response
    if (data.candidates && data.candidates[0]?.content?.parts?.[0]?.text) {
      const dialogue = data.candidates[0].content.parts[0].text.trim();
      return res.json({
        dialogue: dialogue,
        context: context
      });
    }

    // Fallback responses based on context
    const fallbacks = {
      success: 'Excellent clarity, Citizen!',
      error: 'A moment of confusion. Try again!',
      struggle: 'The Party believes in your potential!',
      mastery: 'Mastery achieved! The Party celebrates!',
      introduction: 'Let me explain this Clarity Standard!',
      warning: 'Your metrics require attention, Citizen.',
      encouragement: 'Keep processing, Citizen!',
      observation: 'PEARL is observing...',
      greeting: 'Welcome, Citizen!',
      farewell: 'The Party thanks you for your service!'
    };

    res.json({
      dialogue: fallbacks[context] || 'The Party is always watching.',
      context: context
    });

  } catch (error) {
    console.error('PEARL dialogue error:', error);
    res.status(500).json({ error: 'PEARL dialogue failed', message: error.message });
  }
});

// =============================================================================
// Start Server
// =============================================================================

app.listen(PORT, () => {
  console.log(`Proxy server running on port ${PORT}`);
  console.log(`Anthropic API: ${ANTHROPIC_API_KEY ? 'configured' : 'NOT configured'}`);
  console.log(`Gemini API: ${GEMINI_API_KEY ? 'configured' : 'NOT configured'}`);
});
