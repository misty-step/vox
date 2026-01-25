"use client";

import { useEffect, useState } from "react";

function MicIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
      <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
      <line x1="12" y1="19" x2="12" y2="23" />
      <line x1="8" y1="23" x2="16" y2="23" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

function PencilIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M12 20h9" />
      <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" />
    </svg>
  );
}

function ClipboardIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
    </svg>
  );
}

function SunIcon() {
  return (
    <svg
      className="sun-icon"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <circle cx="12" cy="12" r="5" />
      <line x1="12" y1="1" x2="12" y2="3" />
      <line x1="12" y1="21" x2="12" y2="23" />
      <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
      <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
      <line x1="1" y1="12" x2="3" y2="12" />
      <line x1="21" y1="12" x2="23" y2="12" />
      <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
      <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
    </svg>
  );
}

function MoonIcon() {
  return (
    <svg
      className="moon-icon"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
    </svg>
  );
}

function ThemeToggle() {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const toggleTheme = () => {
    const html = document.documentElement;
    const current = html.getAttribute("data-theme");
    const next = current === "dark" ? "light" : "dark";
    html.setAttribute("data-theme", next);
    localStorage.setItem("theme", next);
  };

  if (!mounted) {
    return (
      <button className="theme-toggle" aria-label="Toggle theme">
        <SunIcon />
        <MoonIcon />
      </button>
    );
  }

  return (
    <button
      className="theme-toggle"
      onClick={toggleTheme}
      aria-label="Toggle theme"
    >
      <SunIcon />
      <MoonIcon />
    </button>
  );
}

export default function Page() {
  return (
    <>
      <header>
        <div className="container">
          <span className="logo">Vox</span>
          <div className="header-right">
            <ThemeToggle />
            <nav>
              <a href="#pricing">Pricing</a>
              <a href="mailto:hello@mistystep.io">Contact</a>
            </nav>
          </div>
        </div>
      </header>

      <section className="hero">
        <div className="container">
          <div className="hero-grid">
            <div>
              <h1>
                Say it messy.
                <br />
                Get it clean.
              </h1>
              <p className="subtitle">
                Dictation that cleans up after you. Talk naturally, get polished
                text at your cursor. Fast.
              </p>
              <div className="cta-row">
                <a
                  href={
                    process.env.NEXT_PUBLIC_DOWNLOAD_URL ||
                    "https://fxdbconfwe9gnaws.public.blob.vercel-storage.com/releases/Vox-latest.dmg"
                  }
                  className="cta primary"
                >
                  Download for macOS
                </a>
                <a href="#features" className="cta secondary">
                  See how it works
                </a>
              </div>
            </div>
            <div className="demo-card">
              <div className="demo-label">
                <MicIcon />
                Before
              </div>
              <p className="demo-input">
                &ldquo;So basically what I&apos;m trying to say is, um, the API
                needs to like handle errors better, you know?&rdquo;
              </p>
              <div className="demo-label">
                <CheckIcon />
                After
              </div>
              <p className="demo-output">
                The API needs better error handling.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="features" id="features">
        <div className="container">
          <div className="feature">
            <div className="feature-icon">
              <MicIcon />
            </div>
            <h3>Transcribe</h3>
            <p>
              High-fidelity speech recognition that captures what you actually
              said. Accurate and fast.
            </p>
          </div>
          <div className="feature">
            <div className="feature-icon">
              <PencilIcon />
            </div>
            <h3>Clean up</h3>
            <p>
              Remove ums, likes, and filler words. Compress ramblings into
              tight, articulate text.
            </p>
          </div>
          <div className="feature">
            <div className="feature-icon">
              <ClipboardIcon />
            </div>
            <h3>Paste</h3>
            <p>
              Text appears at your cursor in under a second. No plugins, no app
              switching.
            </p>
          </div>
        </div>
      </section>

      <section className="pricing" id="pricing">
        <div className="container">
          <h2>Simple, transparent pricing</h2>
          <p className="pricing-subtitle">
            Start with a free trial. Upgrade when you&apos;re ready.
          </p>
          <div className="pricing-cards">
            <div className="pricing-card">
              <h3>Trial</h3>
              <div className="price">
                <span className="price-amount">Free</span>
                <span className="price-period">for 14 days</span>
              </div>
              <ul className="pricing-features">
                <li>
                  <CheckIcon />
                  Unlimited dictation
                </li>
                <li>
                  <CheckIcon />
                  AI text cleanup
                </li>
                <li>
                  <CheckIcon />
                  Instant paste
                </li>
              </ul>
              <a
                href={process.env.NEXT_PUBLIC_DOWNLOAD_URL || "#"}
                className="cta primary"
              >
                Start free trial
              </a>
            </div>
            <div className="pricing-card featured">
              <div className="pricing-badge">Most Popular</div>
              <h3>Pro</h3>
              <div className="price">
                <span className="price-amount">$9</span>
                <span className="price-period">/month</span>
              </div>
              <ul className="pricing-features">
                <li>
                  <CheckIcon />
                  Everything in Trial
                </li>
                <li>
                  <CheckIcon />
                  Unlimited usage
                </li>
                <li>
                  <CheckIcon />
                  Priority support
                </li>
              </ul>
              <a
                href={process.env.NEXT_PUBLIC_DOWNLOAD_URL || "#"}
                className="cta primary"
              >
                Get Vox Pro
              </a>
            </div>
          </div>
        </div>
      </section>

      <footer>
        <div className="container">
          <span>
            A <a href="https://mistystep.io">Misty Step</a> project
          </span>
          <a href="mailto:hello@mistystep.io">hello@mistystep.io</a>
        </div>
      </footer>
    </>
  );
}
