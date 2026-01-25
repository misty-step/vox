import { redirect } from "next/navigation";

const DEFAULT_DOWNLOAD_URL =
  "https://fxdbconfwe9gnaws.public.blob.vercel-storage.com/releases/Vox-latest.dmg";

export function GET() {
  const url = process.env.DOWNLOAD_URL || DEFAULT_DOWNLOAD_URL;
  redirect(url);
}
