// Checks that LLM output is a rewrite of the transcript, not an answer/response.
// Returns { pass, score, reason } per Promptfoo assertion contract.

module.exports = (output, _context) => {
  const answerMarkers = [
    /^(here|sure|certainly|of course|absolutely)/i,
    /^\d+\.\s/m,    // numbered list
    /^[-\u2022*]\s/m, // bullet list
    /```/,           // code blocks
    /\b(I can help|let me|I'll|I would|I'd be happy)\b/i,
    /\b(here are|here is|here's)\b/i,
    /\b(as an AI|as a language model|as an assistant)\b/i,
  ];

  const matched = answerMarkers.filter((m) => m.test(output));
  const isAnswer = matched.length > 0;

  return {
    pass: !isAnswer,
    score: isAnswer ? 0 : 1,
    reason: isAnswer
      ? `Output appears to be an answer/response rather than a rewrite (matched ${matched.length} marker(s))`
      : "Output is a rewrite, not an answer",
  };
};
