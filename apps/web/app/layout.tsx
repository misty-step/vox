import "./globals.css";
import { Inter } from "next/font/google";

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-inter"
});

export const metadata = {
  title: "Vox - Say it messy. Get it clean.",
  description:
    "Dictation that cleans up after you. Talk naturally, get polished text at your cursor. Fast.",
  openGraph: {
    title: "Vox - Say it messy. Get it clean.",
    description:
      "Dictation that cleans up after you. Talk naturally, get polished text at your cursor. Fast.",
    type: "website"
  }
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={inter.variable} suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                try {
                  var theme = localStorage.getItem('theme');
                  if (theme === 'dark' || (!theme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
                    document.documentElement.setAttribute('data-theme', 'dark');
                  }
                } catch (e) {}
              })();
            `
          }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
