"use client";

import { SignIn, useAuth, useClerk } from "@clerk/nextjs";
import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";

function DesktopAuthContent() {
  const { isSignedIn, getToken } = useAuth();
  const { session } = useClerk();
  const searchParams = useSearchParams();
  const [status, setStatus] = useState<"loading" | "signin" | "redirecting" | "error">("loading");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!isSignedIn) {
      setStatus("signin");
      return;
    }

    async function redirectToApp() {
      try {
        setStatus("redirecting");

        const token = await getToken();
        if (!token) {
          setStatus("error");
          setErrorMessage("Failed to get session token");
          return;
        }

        const redirectUri = searchParams.get("redirect") || "vox://auth";
        const deepLink = `${redirectUri}?token=${encodeURIComponent(token)}`;

        window.location.href = deepLink;
      } catch (err) {
        setStatus("error");
        setErrorMessage(err instanceof Error ? err.message : "Authentication failed");
      }
    }

    redirectToApp();
  }, [isSignedIn, getToken, session, searchParams]);

  if (status === "loading") {
    return <AuthCard><p>Loading...</p></AuthCard>;
  }

  if (status === "signin") {
    return (
      <AuthCard>
        <h1>Sign in to Vox</h1>
        <p className="auth-subtitle">Sign in to connect your desktop app</p>
        <SignIn routing="hash" />
      </AuthCard>
    );
  }

  if (status === "redirecting") {
    return (
      <AuthCard>
        <h1>Success!</h1>
        <p>Redirecting to Vox...</p>
        <p className="auth-hint">If the app doesn&apos;t open, make sure Vox is installed.</p>
      </AuthCard>
    );
  }

  return (
    <AuthCard error>
      <h1>Something went wrong</h1>
      <p>{errorMessage || "Please try again"}</p>
      <button onClick={() => window.location.reload()}>Try Again</button>
    </AuthCard>
  );
}

function AuthCard({ children, error }: { children: React.ReactNode; error?: boolean }) {
  return (
    <>
      <div className={`auth-card ${error ? "error" : ""}`}>{children}</div>
      <style jsx>{`
        .auth-card {
          background: #fff;
          border-radius: 12px;
          padding: 2rem;
          max-width: 400px;
          width: 100%;
          text-align: center;
        }
        .auth-card.error {
          border: 2px solid #dc3545;
        }
        .auth-card :global(h1) {
          margin: 0 0 0.5rem;
          font-size: 1.5rem;
          color: #1a1a2e;
        }
        .auth-card.error :global(h1) {
          color: #dc3545;
        }
        .auth-card :global(.auth-subtitle) {
          margin: 0 0 1.5rem;
          color: #666;
          font-size: 0.9rem;
        }
        .auth-card :global(.auth-hint) {
          margin-top: 1rem;
          color: #999;
          font-size: 0.8rem;
        }
        .auth-card :global(button) {
          margin-top: 1rem;
          padding: 0.75rem 1.5rem;
          background: #1a1a2e;
          color: #fff;
          border: none;
          border-radius: 6px;
          cursor: pointer;
        }
        .auth-card :global(button:hover) {
          background: #16213e;
        }
      `}</style>
    </>
  );
}

function AuthContainer({ children }: { children: React.ReactNode }) {
  return (
    <>
      <div className="auth-container">{children}</div>
      <style jsx>{`
        .auth-container {
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
          padding: 1rem;
        }
      `}</style>
    </>
  );
}

export default function DesktopAuthPage() {
  return (
    <AuthContainer>
      <Suspense fallback={<AuthCard><p>Loading...</p></AuthCard>}>
        <DesktopAuthContent />
      </Suspense>
    </AuthContainer>
  );
}
