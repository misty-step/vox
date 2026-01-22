type AuthResult =
  | { ok: true; subject: string }
  | { ok: false; response: Response };

export function requireTestToken(request: Request): AuthResult {
  const expected = process.env.VOX_TEST_TOKEN;
  if (!expected) {
    return {
      ok: false,
      response: Response.json(
        { error: "auth_not_configured" },
        { status: 501 }
      )
    };
  }

  const header = request.headers.get("authorization") ?? "";
  if (!header.startsWith("Bearer ")) {
    return {
      ok: false,
      response: Response.json({ error: "missing_token" }, { status: 401 })
    };
  }

  const token = header.slice("Bearer ".length).trim();
  if (token !== expected) {
    return {
      ok: false,
      response: Response.json({ error: "invalid_token" }, { status: 403 })
    };
  }

  return { ok: true, subject: "test-user" };
}
