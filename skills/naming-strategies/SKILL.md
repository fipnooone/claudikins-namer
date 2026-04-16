---
name: naming-strategies
description: Use when generating brand/product names. Contains 7 naming strategies, phonetic analysis criteria, and scoring methodology.
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Naming Strategies Methodology

## Overview

This skill provides the naming methodology for claudikins-namer. It defines 7 distinct strategies for generating brand and product names, criteria for phonetic analysis, and a weighted scoring system for evaluating candidates.

## The 7 Naming Strategies

Each strategy approaches name generation from a different angle. The right strategy depends on the brief — industry, tone, audience, and brand positioning.

| #   | Strategy                  | Core Idea                                 | Example                   |
| --- | ------------------------- | ----------------------------------------- | ------------------------- |
| 1   | Neologisms                | Invented words with no prior meaning      | Kodak, Xerox, Spotify     |
| 2   | Compound words            | Two real words merged together            | Facebook, YouTube, AirBnB |
| 3   | Metaphors/analogies       | Words borrowed from another domain        | Amazon, Apple, Jaguar     |
| 4   | Acronyms                  | Shortened from key words                  | IBM, BMW, IKEA            |
| 5   | Word modifications        | Altered real words                        | Tumblr, Flickr, Lyft      |
| 6   | Foreign language          | Borrowings from other languages           | Audi, Volvo, Lego         |
| 7   | Evocative/sound symbolism | Names that sound like what they represent | Zoom, Slack, Crash        |

Full details with generation techniques: [strategies.md](references/strategies.md)

## Smart Strategy Selection

Not every strategy fits every brief. Use these signals to narrow down:

| Signal                | Recommended Strategies                        | Avoid                         |
| --------------------- | --------------------------------------------- | ----------------------------- |
| Tech / innovation     | Neologisms, Compound words                    | Foreign language              |
| Premium / luxury      | Foreign language, Metaphors                   | Acronyms, Word modifications  |
| Consumer / playful    | Word modifications, Compound words, Evocative | Acronyms                      |
| B2B / corporate       | Acronyms, Neologisms                          | Evocative, Word modifications |
| Action / energy       | Evocative/sound symbolism, Neologisms         | Acronyms                      |
| Emotional / lifestyle | Metaphors/analogies, Foreign language         | Acronyms                      |
| Descriptive / clear   | Compound words                                | Neologisms, Foreign language  |

**Industry modifiers:**

- **Healthcare:** Favour Latin/Greek roots (Foreign language), soft consonants
- **Finance:** Favour stability signals — Compound words, Metaphors with weight
- **Gaming:** Favour Evocative, Neologisms with hard consonants
- **Food/beverage:** Favour sensory names — Evocative, Metaphors, open vowels

## Name-Crafter Agent Guidelines

Each name-crafter agent receives ONE strategy assignment and generates **5-8 names** using that strategy exclusively. This constraint ensures:

1. **Depth over breadth** — Focused exploration within one strategy produces better candidates than shallow passes across many
2. **Distinct results** — Multiple agents with different strategies naturally produce diverse candidate pools
3. **Clear attribution** — Every name can be traced back to its generation strategy for analysis

The agent should:

- Apply the strategy's specific generation techniques from [strategies.md](references/strategies.md)
- Evaluate each name against phonetic criteria from [phonetics.md](references/phonetics.md)
- Score each name using the methodology in [scoring.md](references/scoring.md)
- Discard names scoring below 5.0 and replace them

## Evaluation

All generated names are scored using weighted criteria covering memorability, pronounceability, uniqueness, relevance, emotional impact, scalability, and domain-friendliness.

Full scoring methodology: [scoring.md](references/scoring.md)

Phonetic analysis criteria: [phonetics.md](references/phonetics.md)

## References

- [strategies.md](references/strategies.md) — Detailed description of all 7 naming strategies
- [phonetics.md](references/phonetics.md) — Phonetic analysis criteria and cross-language considerations
- [scoring.md](references/scoring.md) — Weighted scoring methodology and thresholds
