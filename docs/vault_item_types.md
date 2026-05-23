# Vault Item Types

This list combines current in-app support with common industry baseline types from Bitwarden, 1Password, and Proton Pass documentation.

## Supported Now (Nija MVP)

- Login
  - For website/app credentials.
  - Typical fields: title, username/email, password, website, notes.
- Card
  - For credit/debit card details.
  - Typical fields: card number, name, expiry, CVV, billing note.
- Identity
  - For personal identity records.
  - Typical fields: full name, document number, country, expiry, address/contact.
- Secure Note / Document
  - For freeform sensitive information using structured note blocks.
  - Block types: heading, paragraph, bullet, checklist, quote.

## Recommended Next Types (Priority Order)

1. Password (standalone secret)
2. Bank Account
3. Passport
4. Driver License
5. SSH Key
6. API Key / Token
7. Wi-Fi Credentials
8. Server/Database Credential
9. Software License Key
10. Address Profile (autofill profile)

## Deferred / Optional

- Alias email entries (if email-alias feature is added)
- Attachments per item
- Passkeys as first-class entry type

## Source Notes

- Bitwarden: Login, Card, Identity, Secure Note, SSH Key.
- 1Password: Common categories include Login, Secure Note, Credit Card, Identity.
- Proton Pass: Login, alias, credit card, secure note, password.

Nija keeps a minimal user-centric surface in MVP, then expands by demand.
