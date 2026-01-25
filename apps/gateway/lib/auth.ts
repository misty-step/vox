import { verifyToken } from "@clerk/backend";

const IS_DEV = process.env.NODE_ENV !== "production";

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

  // Dev mode only: allow test token bypass
  const testToken = process.env.VOX_TEST_TOKEN;
  if (IS_DEV && testToken && token === testToken) {
    return { ok: true, subject: "test-user" };
  }

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

// Keep legacy function for backwards compatibility during migration
// Only works in non-production environments
export function requireTestToken(request: Request): AuthResult {
  if (!IS_DEV) {
    return {
      ok: false,
      response: Response.json({ error: "test_auth_disabled" }, { status: 403 }),
    };
  }

  const expected = process.env.VOX_TEST_TOKEN;
  if (!expected) {
    return {
      ok: false,
      response: Response.json({ error: "auth_not_configured" }, { status: 501 }),
    };
  }

  const header = request.headers.get("authorization") ?? "";
  if (!header.startsWith("Bearer ")) {
    return {
      ok: false,
      response: Response.json({ error: "missing_token" }, { status: 401 }),
    };
  }

  const token = header.slice("Bearer ".length).trim();
  if (token !== expected) {
    return {
      ok: false,
      response: Response.json({ error: "invalid_token" }, { status: 403 }),
    };
  }

  return { ok: true, subject: "test-user" };
}
