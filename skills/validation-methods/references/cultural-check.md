# Cultural and Linguistic Analysis

## Method: AI Analysis by Brand-Reporter Agent (Opus)

This check is performed entirely by Opus AI reasoning. No MCP tools or external services are required — cultural analysis is always available regardless of tooling.

## What to Check

### 1. Negative Meanings

Does the name mean something bad in major languages?

Check these languages (in priority order, focus on target market languages first):

- English
- Spanish
- French
- German
- Chinese (Mandarin)
- Japanese
- Arabic
- Russian
- Hindi
- Portuguese

### 2. Profanity Similarity

Does the name sound like a profanity or vulgar term in any language? Consider both exact matches and phonetic similarity.

### 3. Unfortunate Associations

- Historical events or figures with negative connotations
- Political movements or ideologies
- Cultural or religious taboos
- Tragic events or disasters

### 4. Phonetic Confusion

Could the name be mistaken for an existing brand when spoken aloud? This matters for word-of-mouth marketing and voice search.

### 5. Gender/Age Connotations

Does the name skew masculine/feminine or young/old? This is not necessarily a problem but should be flagged if it conflicts with the target audience.

## Severity Levels

| Level       | Color  | Meaning                                   | Action          |
| ----------- | ------ | ----------------------------------------- | --------------- |
| **FLAG**    | Red    | Known offensive meaning or association    | Reject the name |
| **WARNING** | Yellow | Potential issue, needs human verification | Flag for review |
| **CLEAR**   | Green  | No issues found in AI analysis            | Proceed         |

## Limitations Disclaimer

Every cultural check result MUST include this disclaimer:

> "This analysis is AI-generated based on training data up to May 2025. For production use, professional native-speaker review is recommended for target markets."

This disclaimer is non-negotiable. AI cultural analysis is a useful first pass but cannot replace human expertise for final brand decisions.

## Output Format

```json
{
  "name": "BrandName",
  "status": "clear|warning|flag",
  "confidence": "ai-assessed",
  "issues": [
    {
      "language": "Spanish",
      "issue": "Sounds similar to...",
      "severity": "warning"
    }
  ],
  "disclaimer": "AI analysis — professional native-speaker review recommended"
}
```

When no issues are found, the `issues` array should be empty and `status` should be `"clear"`. The `confidence` field is always `"ai-assessed"` for cultural checks.
