// Checks that the output preserves content words from the input transcript.
// Filters out stop words and fillers, then measures overlap ratio.
// Returns { pass, score, reason } per Promptfoo assertion contract.

// NOTE: stop word list mirrors Sources/VoxCore/RewriteQualityGate.swift.
// "not"/"no" intentionally excluded to catch negation-flipping rewrites.

module.exports = (output, context) => {
  const stopWords = new Set([
    "a", "an", "the", "is", "it", "in", "on", "at", "to", "of",
    "and", "or", "but", "so", "if", "do", "my", "me", "we", "he",
    "she", "be", "am", "are", "was", "were", "has", "had", "have",
    "i", "you", "for", "with", "as", "by", "this",
    "that", "from", "up", "out", "just", "then", "than", "very",
    // Common fillers the rewriter should strip:
    "um", "uh", "like", "know", "mean", "basically", "actually",
    "literally", "well", "right", "yeah", "ok", "okay",
  ]);

  function contentWords(text) {
    return text
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((w) => w.length >= 2 && !stopWords.has(w));
  }

  const transcript = context.vars.transcript;
  const inputWords = contentWords(transcript);
  if (inputWords.length === 0) {
    return { pass: true, score: 1, reason: "No content words to check" };
  }

  const outputWords = new Set(contentWords(output));
  const preserved = inputWords.filter((w) => outputWords.has(w)).length;
  const ratio = preserved / inputWords.length;

  return {
    pass: ratio >= 0.5,
    score: ratio,
    reason: `Content word preservation: ${(ratio * 100).toFixed(0)}% (${preserved}/${inputWords.length})`,
  };
};
