export const runtime = "nodejs";

export async function GET() {
  return Response.json({
    ok: true,
    service: "vox-gateway",
    time: new Date().toISOString()
  });
}
