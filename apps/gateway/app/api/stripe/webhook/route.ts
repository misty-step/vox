export const runtime = "nodejs";

export async function POST(request: Request) {
  const signature = request.headers.get("stripe-signature");
  if (!signature) {
    return Response.json({ error: "missing_signature" }, { status: 400 });
  }

  const body = await request.text();
  if (!body) {
    return Response.json({ error: "empty_body" }, { status: 400 });
  }

  return Response.json({ received: true });
}
