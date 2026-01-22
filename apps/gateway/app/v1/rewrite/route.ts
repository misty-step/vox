import { requireTestToken } from "../../../lib/auth";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const auth = requireTestToken(request);
  if (!auth.ok) {
    return auth.response;
  }

  return Response.json(
    { error: "rewrite_not_implemented", subject: auth.subject },
    { status: 501 }
  );
}
