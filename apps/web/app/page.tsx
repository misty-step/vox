export default function Page() {
  return (
    <main>
      <div className="orb" aria-hidden="true" />
      <section className="hero">
        <div>
          <span className="pill">Vox for macOS</span>
          <h1 className="title">Speak. Rewrite. Paste. Instantly.</h1>
          <p className="subtitle">
            Vox is the invisible editor for macOS. Hit a hotkey, dictate, and
            get clean text at your cursor. No copy‑paste gymnastics, no
            attention tax.
          </p>
          <div className="cta-row">
            <a className="cta primary" href="#">
              Download for macOS
            </a>
            <a className="cta secondary" href="#">
              Join the private beta
            </a>
          </div>
        </div>
        <div className="panel">
          <h3>Why it feels different</h3>
          <p>
            Vox only does the critical loop: record → transcribe → rewrite →
            paste. Everything else is out of the way. The app disappears, the
            text stays.
          </p>
        </div>
      </section>

      <section className="grid">
        <div className="panel">
          <h3>Zero‑context editing</h3>
          <p>Works wherever your cursor is. No plugin wars.</p>
        </div>
        <div className="panel">
          <h3>Rewrite levels</h3>
          <p>Light cleanup to aggressive polish, instant fallback to raw.</p>
        </div>
        <div className="panel">
          <h3>Privacy‑first</h3>
          <p>No audio retention by default. Redacted logs by default.</p>
        </div>
        <div className="panel">
          <h3>Fast activation</h3>
          <p>Buy once, get a token, and ship. No accounts required.</p>
        </div>
      </section>

      <section className="footer">
        <span>Built for macOS 13+</span>
        <span>Downloadable DMG + license activation</span>
        <span>Questions: hello@vox.app</span>
      </section>
    </main>
  );
}
