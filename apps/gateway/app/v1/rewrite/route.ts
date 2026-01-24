import { requireAuth } from "../../../lib/auth";
import { requireEntitlement } from "../../../lib/entitlements";

export const runtime = "nodejs";

interface RewriteRequestBody {
  sessionId: string;
  locale: string;
  transcript: { text: string };
  context: string;
  processingLevel: "off" | "light" | "aggressive";
}

interface GeminiRequest {
  contents: Array<{ role: string; parts: Array<{ text: string }> }>;
  systemInstruction: { parts: Array<{ text: string }> };
  generationConfig: {
    temperature: number;
    maxOutputTokens: number;
  };
}

interface GeminiResponse {
  candidates?: Array<{
    content: {
      parts: Array<{ text?: string }>;
    };
  }>;
}

function buildPrompt(request: RewriteRequestBody): { systemInstruction: string; userPrompt: string } {
  let systemInstruction: string;

  switch (request.processingLevel) {
    case "light":
      systemInstruction = `You are a precise transcript cleaner. Perform light cleanup only.
Fix punctuation, capitalization, and sentence breaks. Preserve wording, order, and tone.
You may remove obvious filler words, stutters, and repeated short phrases when they add no meaning.
Merge fragmented phrases into full sentences. Keep original meaning and wording.
Do not paraphrase or summarize.
Keep original perspective and tense.
Keep all numbers, names, acronyms, code, and file paths verbatim.
Output only the cleaned transcript with no commentary.`;
      break;

    case "aggressive":
      systemInstruction = `You are an executive editor. Elevate the transcript into concise, high-impact writing for directing a coding agent or LLM.
Preserve meaning and intent. Do not add facts.
Do not change the speech act: statements stay statements, questions stay questions, commands stay commands.
Keep the original perspective and modality (I/we/you, can/could/should/might).
Keep every specific noun, name, number, requirement, and constraint. Do not drop any.
You may reorder for clarity and remove filler words.
If unsure about a phrase, keep the original wording.
Output only the rewritten text with no commentary.`;
      break;

    case "off":
    default:
      systemInstruction = `You are an expert editor. Rewrite the transcript into clear, articulate text while preserving meaning.
Do not add new facts. Do not invent details. Keep it faithful.
Output only the rewritten text with no commentary.`;
      break;
  }

  let userPrompt = `Transcript:\n<<<\n${request.transcript.text}\n>>>\n`;
  const trimmedContext = request.context?.trim() || "";
  if (trimmedContext) {
    userPrompt += `\nContext:\n<<<\n${trimmedContext}\n>>>\n`;
  }
  userPrompt += "\nRewrite now.";

  return { systemInstruction, userPrompt };
}

export async function POST(request: Request) {
  const auth = await requireAuth(request);
  if (!auth.ok) {
    return auth.response;
  }

  // Check entitlement before allowing rewrite
  const entitlement = await requireEntitlement(auth.subject, auth.email, "rewrite");
  if (!entitlement.ok) {
    return Response.json(
      { error: entitlement.error },
      { status: entitlement.statusCode }
    );
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return Response.json({ error: "gemini_not_configured" }, { status: 501 });
  }

  const modelId = process.env.GEMINI_MODEL_ID || "gemini-2.0-flash";
  const temperature = parseFloat(process.env.GEMINI_TEMPERATURE || "0.7");
  const maxOutputTokens = parseInt(process.env.GEMINI_MAX_TOKENS || "65536", 10);

  let body: RewriteRequestBody;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  if (!body.transcript?.text) {
    return Response.json({ error: "missing_transcript" }, { status: 400 });
  }

  const { systemInstruction, userPrompt } = buildPrompt(body);

  const geminiPayload: GeminiRequest = {
    contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    systemInstruction: { parts: [{ text: systemInstruction }] },
    generationConfig: {
      temperature,
      maxOutputTokens,
    },
  };

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${modelId}:generateContent`;

  try {
    const geminiResponse = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify(geminiPayload),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error(`Gemini API error ${geminiResponse.status}:`, errorText);
      return Response.json(
        { error: "gemini_api_error", status: geminiResponse.status },
        { status: 502 }
      );
    }

    const geminiData: GeminiResponse = await geminiResponse.json();
    const parts = geminiData.candidates?.[0]?.content?.parts || [];
    const finalText = parts
      .map((p) => p.text || "")
      .join("")
      .trim();

    if (!finalText) {
      return Response.json({ error: "empty_response" }, { status: 502 });
    }

    return Response.json({
      finalText,
      subject: auth.subject,
      sessionId: body.sessionId,
    });
  } catch (error) {
    console.error("Rewrite error:", error);
    return Response.json({ error: "rewrite_failed" }, { status: 500 });
  }
}
