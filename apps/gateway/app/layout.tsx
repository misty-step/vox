export const metadata = {
  title: "Vox Gateway",
  description: "API gateway for Vox."
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
