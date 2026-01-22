import { requireTestToken } from "../../../lib/auth";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const auth = requireTestToken(request);
  if (!auth.ok) {
    return auth.response;
  }

  return Response.json({
    subject: auth.subject,
    plan: "trial",
    status: "active",
    features: ["rewrite", "stt"]
  });
}
