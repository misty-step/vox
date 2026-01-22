export const runtime = "nodejs";

export async function GET() {
  return Response.json({
    stt: { provider: "elevenlabs", directUpload: true },
    rewrite: { provider: "gemini" },
    processingLevels: ["off", "light", "aggressive"]
  });
}
