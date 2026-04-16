# SEO Uniqueness / "Googleability" Analysis

## Primary Method: MCP (Gemini Google Search)

The most reliable way to assess SEO uniqueness is through the Gemini Google Search tool via the tool-executor MCP plugin.

### How to Use

Follow the standard tool-executor workflow:

```
1. search_tools("google search") → find the Gemini search tool
2. get_tool_schema(<tool_id from step 1>) → get exact input parameters
3. execute_code(<tool_id>, { query: "\"BrandName\"" }) → run the search
```

This returns Gemini-based tools that can perform Google searches and return structured results.

### Search Strategy

1. Query the exact brand name in quotes: `"BrandName"`
2. Analyze the results:
   - **Total results count** — how crowded is the namespace?
   - **Top 10 results relevance** — are they related to the same industry/domain?
3. Low result count + unrelated top results = high SEO potential
4. High result count + related top results = low SEO potential (name is crowded)

## Fallback Without MCP: WebSearch Tool

If the tool-executor MCP plugin is not available, use Claude Code's built-in WebSearch tool.

```
WebSearch("\"BrandName\"")
```

WebSearch provides less structured data than Gemini but still gives a useful indication of the search landscape. Results from this method should be marked as `"confidence": "partial"`.

If neither MCP nor WebSearch is available, mark as `"confidence": "unchecked"`.

## Scoring

| SEO Score | Results Count            | Competition Level           |
| --------- | ------------------------ | --------------------------- |
| 9-10      | < 100 results            | No relevant competition     |
| 7-8       | 100 - 1,000 results      | Minimal competition         |
| 5-6       | 1,000 - 10,000 results   | Some competition            |
| 3-4       | 10,000 - 100,000 results | Significant competition     |
| 1-2       | > 100,000 results        | Dominated by existing brand |

The score reflects how easily a new brand could rank on the first page for its own name. A score of 7+ means the brand can likely own its search results within months. A score below 4 means an established competitor already dominates the namespace.

## Output Format

```json
{
  "name": "BrandName",
  "seo_score": 8,
  "results_count": 450,
  "top_competitors": ["unrelated site 1", "unrelated site 2"],
  "method": "gemini|websearch|unchecked",
  "confidence": "verified|partial|unchecked"
}
```
