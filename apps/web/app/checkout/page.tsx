"use client";

import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";

type CheckoutStatus = "loading" | "redirecting" | "error";

function CheckoutContent() {
  const searchParams = useSearchParams();
  const [status, setStatus] = useState<CheckoutStatus>("loading");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    const token = searchParams.get("token");

    if (!token) {
      setStatus("error");
      setErrorMessage("Missing authentication token. Please try again from the Vox app.");
      return;
    }

    async function initiateCheckout() {
      try {
        setStatus("loading");

        const gatewayUrl = process.env.NEXT_PUBLIC_GATEWAY_URL;
        if (!gatewayUrl) {
          throw new Error("Gateway URL not configured");
        }

        // Call gateway to create Stripe checkout session
        const response = await fetch(`${gatewayUrl}/api/stripe/checkout`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            successUrl: `${window.location.origin}/checkout/success`,
            cancelUrl: `${window.location.origin}/checkout?token=${encodeURIComponent(token)}&cancelled=true`,
          }),
        });

        if (!response.ok) {
          const data = await response.json().catch(() => ({}));
          if (response.status === 401) {
            throw new Error("Session expired. Please sign in again from the Vox app.");
          }
          throw new Error(data.error || `Checkout failed (${response.status})`);
        }

        const { checkoutUrl } = await response.json();

        if (!checkoutUrl) {
          throw new Error("No checkout URL received");
        }

        setStatus("redirecting");
        window.location.href = checkoutUrl;
      } catch (err) {
        setStatus("error");
        setErrorMessage(err instanceof Error ? err.message : "Something went wrong");
      }
    }

    // Check if returning from cancelled checkout
    const cancelled = searchParams.get("cancelled");
    if (cancelled === "true") {
      setStatus("error");
      setErrorMessage("Checkout was cancelled. Click below to try again.");
      return;
    }

    initiateCheckout();
  }, [searchParams]);

  if (status === "loading") {
    return (
      <CheckoutCard>
        <div className="spinner" />
        <h1>Preparing checkout...</h1>
        <p>Please wait while we set up your subscription.</p>
      </CheckoutCard>
    );
  }

  if (status === "redirecting") {
    return (
      <CheckoutCard>
        <div className="spinner" />
        <h1>Redirecting to payment...</h1>
        <p>You&apos;ll be redirected to Stripe to complete your purchase.</p>
      </CheckoutCard>
    );
  }

  const token = searchParams.get("token");

  return (
    <CheckoutCard error>
      <h1>Checkout Error</h1>
      <p>{errorMessage}</p>
      {token && (
        <button
          onClick={() => {
            window.location.href = `/checkout?token=${encodeURIComponent(token)}`;
          }}
        >
          Try Again
        </button>
      )}
      <p className="hint">
        Having trouble? Contact{" "}
        <a href="mailto:support@mistystep.io">support@mistystep.io</a>
      </p>
    </CheckoutCard>
  );
}

function CheckoutCard({
  children,
  error,
}: {
  children: React.ReactNode;
  error?: boolean;
}) {
  return (
    <>
      <div className={`checkout-card ${error ? "error" : ""}`}>{children}</div>
      <style jsx>{`
        .checkout-card {
          background: #fff;
          border-radius: 12px;
          padding: 2.5rem;
          max-width: 420px;
          width: 100%;
          text-align: center;
        }
        .checkout-card.error {
          border: 2px solid #dc3545;
        }
        .checkout-card :global(h1) {
          margin: 1rem 0 0.5rem;
          font-size: 1.5rem;
          color: #1a1a2e;
        }
        .checkout-card.error :global(h1) {
          color: #dc3545;
        }
        .checkout-card :global(p) {
          margin: 0.5rem 0;
          color: #666;
          font-size: 0.95rem;
        }
        .checkout-card :global(.hint) {
          margin-top: 1.5rem;
          font-size: 0.85rem;
          color: #999;
        }
        .checkout-card :global(.hint a) {
          color: #666;
        }
        .checkout-card :global(button) {
          margin-top: 1.5rem;
          padding: 0.75rem 2rem;
          background: #1a1a2e;
          color: #fff;
          border: none;
          border-radius: 6px;
          cursor: pointer;
          font-size: 1rem;
        }
        .checkout-card :global(button:hover) {
          background: #16213e;
        }
        .checkout-card :global(.spinner) {
          width: 48px;
          height: 48px;
          border: 3px solid #e0e0e0;
          border-top-color: #1a1a2e;
          border-radius: 50%;
          margin: 0 auto;
          animation: spin 1s linear infinite;
        }
        @keyframes spin {
          to {
            transform: rotate(360deg);
          }
        }
      `}</style>
    </>
  );
}

function CheckoutContainer({ children }: { children: React.ReactNode }) {
  return (
    <>
      <div className="checkout-container">{children}</div>
      <style jsx>{`
        .checkout-container {
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

export default function CheckoutPage() {
  return (
    <CheckoutContainer>
      <Suspense
        fallback={
          <CheckoutCard>
            <div className="spinner" />
            <h1>Loading...</h1>
          </CheckoutCard>
        }
      >
        <CheckoutContent />
      </Suspense>
    </CheckoutContainer>
  );
}
