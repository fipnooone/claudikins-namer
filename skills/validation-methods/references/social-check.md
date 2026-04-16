# Social Media Handle Availability

## Primary Method: MCP (Apify Username Checker)

The reliable way to check social media handle availability is through the Apify username checker via the tool-executor MCP plugin.

### How to Use

```
search_tools("username availability checker")
```

This returns Apify-based tools that can check username availability across 80+ platforms. The Apify actor handles rate limiting, captchas, and platform-specific quirks.

### Why MCP Is Required

Most social media platforms return HTTP 200 for non-existent usernames (they serve a "user not found" page, not a 404). Reliable checking requires browser automation or platform-specific API integration, which Apify provides.

## Without MCP: Mark as "unchecked"

If the tool-executor MCP plugin is not available:

- **DO NOT** attempt curl-based checking — results are unreliable
- **DO NOT** try to scrape platform pages — most return 200 regardless
- Mark all social media checks as `"status": "unchecked"`
- Add note: `"requires manual verification"`

This is an intentional design decision. Unreliable data is worse than no data.

## Platform Selection by Target Market

Select platforms based on the target market specified in the naming brief.

### Global (always check)

- Twitter/X
- Instagram
- LinkedIn
- GitHub
- TikTok

### US/EU (add to global)

- Facebook
- YouTube
- Pinterest
- Reddit

### CIS/Russia (add to global)

- Telegram
- VK
- OK (Odnoklassniki)

### China (add to global)

- Weibo
- WeChat
- Douyin

### Japan (add to global)

- LINE
- Mixi

If the target market is not specified in the brief, ask the user before running social checks. Platform selection directly affects which handles matter.

## Output Format

```json
{
  "platform": "twitter",
  "handle": "@example",
  "status": "available|taken|unchecked",
  "method": "apify|manual-required"
}
```

Each platform produces its own result object. A complete social check returns an array of these objects, one per platform.
