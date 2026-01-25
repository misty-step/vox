import { requireAuth } from "../../../../lib/auth";
import { requireEntitlement } from "../../../../lib/entitlements";

export const runtime = "nodejs";

const ELEVENLABS_ENDPOINT = "https://api.elevenlabs.io/v1/speech-to-text";

export async function POST(request: Request) {
  const auth = await requireAuth(request);
  if (!auth.ok) {
    return auth.response;
  }

  const entitlement = await requireEntitlement(auth.subject, auth.email, "stt");
  if (!entitlement.ok) {
    return Response.json(
      { error: entitlement.error },
      { status: entitlement.statusCode }
    );
  }

  const apiKey = process.env.ELEVENLABS_API_KEY;
  if (!apiKey) {
    return Response.json({ error: "stt_provider_not_configured" }, { status: 501 });
  }

  let formData: FormData;
  try {
    formData = await request.formData();
  } catch {
    return Response.json({ error: "invalid_form_data" }, { status: 400 });
  }

  const file = formData.get("file");
  if (!(file instanceof File)) {
    return Response.json({ error: "missing_file" }, { status: 400 });
  }

  const modelIdValue = formData.get("model_id");
  const modelId =
    typeof modelIdValue === "string" && modelIdValue.trim()
      ? modelIdValue.trim()
      : "scribe_v1";

  const languageCodeValue = formData.get("language_code");
  const languageCode =
    typeof languageCodeValue === "string" && languageCodeValue.trim()
      ? languageCodeValue.trim()
      : null;

  const sessionIdValue = formData.get("session_id");
  const sessionId =
    typeof sessionIdValue === "string" && sessionIdValue.trim()
      ? sessionIdValue.trim()
      : null;

  const proxyBody = new FormData();
  proxyBody.append("file", file, file.name || "audio");
  proxyBody.append("model_id", modelId);
  if (languageCode) {
    proxyBody.append("language_code", languageCode);
  }
  proxyBody.append("enable_logging", "false");

  try {
    const sttResponse = await fetch(ELEVENLABS_ENDPOINT, {
      method: "POST",
      headers: {
        "xi-api-key": apiKey,
      },
      body: proxyBody,
    });

    if (!sttResponse.ok) {
      const errorText = await sttResponse.text();
      console.error(`ElevenLabs STT error ${sttResponse.status}:`, errorText);
      return Response.json(
        { error: "stt_api_error", status: sttResponse.status },
        { status: 502 }
      );
    }

    let payload: { text?: string; language_code?: string | null };
    try {
      payload = await sttResponse.json();
    } catch (error) {
      console.error("ElevenLabs STT invalid JSON:", error);
      return Response.json({ error: "stt_invalid_response" }, { status: 502 });
    }

    const text = typeof payload.text === "string" ? payload.text : "";
    if (!text) {
      return Response.json({ error: "stt_empty_response" }, { status: 502 });
    }

    const responseLanguageCode =
      typeof payload.language_code === "string" ? payload.language_code : null;

    return Response.json({
      text,
      language_code: responseLanguageCode,
      session_id: sessionId,
    });
  } catch (error) {
    console.error("STT proxy error:", error);
    return Response.json({ error: "stt_proxy_failed" }, { status: 502 });
  }
}
