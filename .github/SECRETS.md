# Required GitHub repository secrets

For Phase 13 CI to function, the maintainer configures these in
GitHub → Settings → Secrets and variables → Actions:

| Secret | Required for | Format |
|--------|--------------|--------|
| `SIGNING_KEYSTORE_BASE64` | Release builds | `base64 -i release.keystore` |
| `SIGNING_KEYSTORE_PASSWORD` | Release builds | plain text |
| `SIGNING_KEY_ALIAS` | Release builds | plain text |
| `SIGNING_KEY_PASSWORD` | Release builds | plain text |
| `SENTRY_DSN` | full-flavor crash reporting | from sentry.io project settings; optional — Sentry no-ops with empty DSN |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console upload | JSON; optional — workflow skips Play upload if absent |
