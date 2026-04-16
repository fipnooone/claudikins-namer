# Domain Availability Checking

## Primary Method: RDAP

RDAP (Registration Data Access Protocol) is the modern replacement for WHOIS. It requires no API key and returns structured JSON responses.

- **Source**: https://about.rdap.org/
- **Endpoint**: `https://rdap.org/domain/{name}.{tld}`
- **HTTP 200** = domain is registered
- **HTTP 404** = domain is available

### Example

```bash
# Check if example.com is registered
curl -s -o /dev/null -w "%{http_code}" https://rdap.org/domain/example.com
# Returns: 200 (registered)

# Check if xyznotreal123.com is available
curl -s -o /dev/null -w "%{http_code}" https://rdap.org/domain/xyznotreal123.com
# Returns: 404 (available)
```

### Coverage

RDAP covers .com, .org, .net, .io and most major TLDs. Coverage depends on the registry supporting RDAP, which most major registries now do.

## Fallback: DNS Lookup

If RDAP is unavailable (5xx errors, timeouts), fall back to DNS lookup.

```bash
# Check DNS records
dig +short example.com
# IP address returned = registered
# Empty response = likely available
```

**Important**: DNS is less reliable than RDAP. A domain can be registered without active DNS records (parked, expired-but-held, etc.). Use DNS only as a fallback, not a primary method.

## TLDs to Check by Default

Check these TLDs for every brand name candidate:

- `.com` — essential for any brand
- `.io` — common for tech/SaaS
- `.app` — mobile/app brands
- `.dev` — developer tools
- `.co` — short alternative to .com

## Error Handling

```
RDAP request →
├── HTTP 200 → registered (status: "taken")
├── HTTP 404 → available (status: "available")
├── HTTP 5xx or timeout →
│   DNS fallback →
│   ├── IP returned → likely registered (status: "taken", method: "dns")
│   ├── Empty → likely available (status: "available", method: "dns")
│   └── Error → mark as "unchecked"
└── Network error → DNS fallback (same as above)
```

## Output Format

```json
{
  "domain": "example.com",
  "status": "available|taken|error",
  "method": "rdap|dns",
  "checked_at": "ISO timestamp"
}
```

Each TLD produces its own result object. A complete domain check returns an array of these objects.
