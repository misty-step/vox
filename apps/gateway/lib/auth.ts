import { verifyToken } from "@clerk/backend";

type AuthResult =
  | { ok: true; subject: string; email?: string }
  | { ok: false; response: Response };

export async function requireAuth(request: Request): Promise<AuthResult> {
  const header = request.headers.get("authorization") ?? "";
  if (!header.startsWith("Bearer ")) {
    return {
      ok: false,
      response: Response.json({ error: "missing_token" }, { status: 401 }),
    };
  }

  const token = header.slice("Bearer ".length).trim();

  // Production: verify Clerk JWT
  const secretKey = process.env.CLERK_SECRET_KEY;
  if (!secretKey) {
    return {
      ok: false,
      response: Response.json({ error: "auth_not_configured" }, { status: 501 }),
    };
  }

  try {
    const payload = await verifyToken(token, {
      secretKey,
      authorizedParties: [], // Allow any audience for now
    });

    return {
      ok: true,
      subject: payload.sub,
      email: payload.email as string | undefined,
    };
  } catch (error) {
    console.error("JWT verification failed:", error);
    return {
      ok: false,
      response: Response.json({ error: "invalid_token" }, { status: 403 }),
    };
  }
}
