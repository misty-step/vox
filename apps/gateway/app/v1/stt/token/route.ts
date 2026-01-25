export const runtime = "nodejs";

export async function POST(request: Request) {
  return Response.json({
    error: "endpoint_deprecated",
    message: "Use /v1/stt/transcribe instead",
  }, { status: 410 });
}
