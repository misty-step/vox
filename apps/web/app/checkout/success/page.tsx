"use client";

import { useEffect, useState } from "react";

export default function CheckoutSuccessPage() {
  const [deepLinkAttempted, setDeepLinkAttempted] = useState(false);

  useEffect(() => {
    // Attempt to open the app via deep link
    const timer = setTimeout(() => {
      window.location.href = "vox://payment-success";
      setDeepLinkAttempted(true);
    }, 1000);

    return () => clearTimeout(timer);
  }, []);

  return (
    <>
      <div className="success-container">
        <div className="success-card">
          <div className="checkmark">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M20 6L9 17l-5-5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <h1>Payment Successful!</h1>
          <p>Thank you for subscribing to Vox Pro.</p>
          <p className="redirect-text">
            {deepLinkAttempted
              ? "Opening Vox..."
              : "Redirecting you back to the app..."}
          </p>
          <button onClick={() => (window.location.href = "vox://payment-success")}>
            Open Vox
          </button>
          <p className="hint">
            If the app doesn&apos;t open automatically, click the button above.
          </p>
        </div>
      </div>
      <style jsx>{`
        .success-container {
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
          padding: 1rem;
        }
        .success-card {
          background: #fff;
          border-radius: 12px;
          padding: 2.5rem;
          max-width: 420px;
          width: 100%;
          text-align: center;
        }
        .checkmark {
          width: 64px;
          height: 64px;
          background: #10b981;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 0 auto 1.5rem;
        }
        .checkmark svg {
          width: 32px;
          height: 32px;
          color: #fff;
        }
        h1 {
          margin: 0 0 0.5rem;
          font-size: 1.5rem;
          color: #1a1a2e;
        }
        p {
          margin: 0.5rem 0;
          color: #666;
          font-size: 0.95rem;
        }
        .redirect-text {
          color: #10b981;
          font-weight: 500;
        }
        button {
          margin-top: 1.5rem;
          padding: 0.75rem 2rem;
          background: #1a1a2e;
          color: #fff;
          border: none;
          border-radius: 6px;
          cursor: pointer;
          font-size: 1rem;
        }
        button:hover {
          background: #16213e;
        }
        .hint {
          margin-top: 1rem;
          font-size: 0.85rem;
          color: #999;
        }
      `}</style>
    </>
  );
}
