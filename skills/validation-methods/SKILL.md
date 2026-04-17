---
name: validation-methods
description: Use when validating brand names. Contains methods for domain checking, social media verification, SEO analysis, and cultural review with MCP fallback logic.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - mcp__plugin_claudikins-tool-executor_tool-executor__search_tools
  - mcp__plugin_claudikins-tool-executor_tool-executor__get_tool_schema
  - mcp__plugin_claudikins-tool-executor_tool-executor__execute_code
---

# Validation Methods

## Overview

This skill provides validation methods for claudikins-namer. It defines how to verify brand name candidates across four categories, with structured fallback logic depending on available tooling (MCP tool-executor plugin vs. standard CLI tools).

## Validation Categories

| Category             | What It Checks                                           | Reference                                         |
| -------------------- | -------------------------------------------------------- | ------------------------------------------------- |
| Domain Availability  | Is the .com/.io/.dev available?                          | [domain-check.md](references/domain-check.md)     |
| Social Media Handles | Are key handles free on target platforms?                | [social-check.md](references/social-check.md)     |
| SEO Uniqueness       | How "googleable" is the name?                            | [seo-check.md](references/seo-check.md)           |
| Cultural Review      | Any negative meanings, associations, or phonetic issues? | [cultural-check.md](references/cultural-check.md) |

Each reference document contains the exact method, commands, fallback logic, and JSON output format for that category.

## MCP Detection Pattern

Before running validation, detect whether the tool-executor MCP plugin is available:

```
search_tools("username availability") → if results returned, MCP is available
```

If the search returns tools, use MCP-based methods (primary path). If it errors or returns nothing, fall back to CLI/AI methods where possible.

## Confidence Levels

Every validation result carries a confidence level:

| Level           | Meaning                           | When Used                                                                          |
| --------------- | --------------------------------- | ---------------------------------------------------------------------------------- |
| **verified**    | Full programmatic check completed | MCP tool returned a definitive result, or RDAP/DNS returned a clear answer         |
| **ai-assessed** | AI reasoning, no external check   | Opus AI analysis (cultural check) — always available but not programmatic          |
| **partial**     | Limited check completed           | Fallback method used (e.g., WebSearch instead of Gemini, DNS instead of RDAP)      |
| **unchecked**   | No check was possible             | MCP unavailable and no reliable fallback exists (e.g., social media without Apify) |

## Fallback Chain

```
MCP available?
├── Yes → Full checks (RDAP + Apify + Gemini + Opus AI)
│         Confidence: verified
└── No →
    ├── Domain: Bash fallback (RDAP via curl, DNS via dig)
    │   Confidence: verified (RDAP) or partial (DNS)
    ├── Social: No reliable fallback
    │   Confidence: unchecked — mark "requires manual verification"
    ├── SEO: WebSearch fallback (if available)
    │   Confidence: partial
    └── Cultural: Opus AI analysis (no external tools needed)
        Confidence: ai-assessed (always available, not programmatic)
```

The cultural check always runs since it relies on Opus AI reasoning, not external services. Its confidence is "ai-assessed" rather than "verified" because AI analysis is not a programmatic check — see the mandatory disclaimer in [cultural-check.md](references/cultural-check.md).
