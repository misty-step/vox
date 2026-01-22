import { requireTestToken } from "../../../../lib/auth";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const auth = requireTestToken(request);
  if (!auth.ok) {
    return auth.response;
  }

  const token = process.env.VOX_STT_PROVIDER_TOKEN;
  if (!token) {
    return Response.json(
      { error: "stt_token_not_configured" },
      { status: 501 }
    );
  }

  return Response.json({
    subject: auth.subject,
    token,
    expiresAt: new Date(Date.now() + 10 * 60 * 1000).toISOString()
  });
}
