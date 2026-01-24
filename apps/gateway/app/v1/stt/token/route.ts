import { requireAuth } from "../../../../lib/auth";
import { requireEntitlement } from "../../../../lib/entitlements";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const auth = await requireAuth(request);
  if (!auth.ok) {
    return auth.response;
  }

  // Check entitlement before providing STT token
  const entitlement = await requireEntitlement(auth.subject, auth.email, "stt");
  if (!entitlement.ok) {
    return Response.json(
      { error: entitlement.error },
      { status: entitlement.statusCode }
    );
  }

  const token = process.env.ELEVENLABS_API_KEY;
  if (!token) {
    return Response.json({ error: "stt_provider_not_configured" }, { status: 501 });
  }

  // Return short-lived token (10 minutes)
  // In production, you'd mint a scoped/temporary token from ElevenLabs
  // For now, we return the API key with a client-side expiry hint
  return Response.json({
    subject: auth.subject,
    token,
    provider: "elevenlabs",
    expiresAt: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
  });
}
