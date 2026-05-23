# Nija — design.md

## Purpose

This document defines the non-negotiable design, UX, architecture, coding, and product principles for Nija.

All engineers, designers, AI coding agents, and contributors must follow these rules.

The goal is consistency.

Agents should NOT deviate from these rules unless explicitly instructed.

---

# 1. Product Vision

## Product Name

# Nija

## Tagline

> Your private digital vault.

## Core Philosophy

Nija is:

* Local-first
* Privacy-first
* User-owned
* Minimal
* Calm
* Trustworthy
* Human-centered

Nija is NOT:

* A flashy cybersecurity app
* A hacker-themed product
* A noisy productivity suite
* A cloud-first SaaS
* A complicated enterprise tool

---

# 2. Core Product Principles

## Principle 1 — User Owns Data

The vault file is the source of truth.

The app is only:

* a reader
* a writer
* a vault manager

The company should never become a dependency for accessing user data.

---

## Principle 2 — Local First

All sensitive operations happen locally.

Examples:

* encryption
* decryption
* search indexing
* note rendering
* password generation

No plaintext leaves the device.

---

## Principle 3 — Simplicity Over Features

Every feature must answer:

> Does this reduce friction or improve trust?

If not, do not build it.

Avoid:

* feature bloat
* unnecessary settings
* gamification
* gimmicks
* excessive customization

---

## Principle 4 — Calm UX

Nija should feel:

* quiet
* focused
* spacious
* reassuring
* premium

NOT:

* cyberpunk
* aggressive
* corporate
* flashy
* cluttered

---

## Principle 5 — Security Without Fear

Avoid fear-based security messaging.

DO:

```text
Your vault is encrypted locally.
```

DO NOT:

```text
Military-grade cyber defense.
```

The app should build confidence, not anxiety.

---

# 3. Brand Identity

## Brand Personality

Nija should feel:

* personal
* private
* elegant
* timeless
* human
* trustworthy

---

## Tone of Voice

### Good

```text
Only you can unlock this vault.
```

```text
Your vault is stored locally.
```

```text
Recovery phrases should be stored offline.
```

### Bad

```text
Quantum-grade encryption activated.
```

```text
Cyber attack prevention enabled.
```

---

## Copywriting Rules

* Use short sentences.
* Avoid technical jargon unless necessary.
* Never exaggerate security.
* Never use “unhackable”.
* Never use “military-grade”.
* Prefer calm instructional language.

---

# 4. UI Design System

## Design Style

### Primary Style

* Minimal
* Mobile-first
* Spacious
* Rounded corners
* Soft contrast
* Large touch targets
* Clear typography hierarchy

---

## Color Rules

### Primary Colors

```text
Background: Zinc/Off-white
Text: Warm black
Accent: Deep graphite
Success: Soft green
Warning: Muted amber
Danger: Soft red
```

Avoid:

* neon colors
* saturated gradients
* bright hacker green
* glowing effects

---

## Typography Rules

### Style

* Clean sans-serif
* Strong readability
* Large headings
* Comfortable line spacing

### Hierarchy

```text
Heading: bold
Body: regular
Metadata: muted
Sensitive fields: strong contrast
```

---

## Spacing Rules

Use generous spacing.

Minimum padding:

```text
16px mobile
24px sections
```

Never cram content tightly.

---

## Corner Radius

Use soft rounded corners consistently.

Examples:

```text
Cards: 24px
Buttons: 16px–20px
Inputs: 16px–20px
Floating actions: circular
```

---

## Shadows

Very subtle shadows only.

No heavy elevation.

---

## Animation Rules

Animations must feel:

* smooth
* subtle
* fast
* intentional

Avoid:

* bouncing
* flashy transitions
* excessive motion

Recommended duration:

```text
150ms–250ms
```

---

# 5. Mobile-First Rules

Nija is mobile-first.

Every screen must be designed for:

```text
390px–430px width first.
```

Desktop/web is secondary.

---

## Touch Rules

Minimum touch target:

```text
44px × 44px
```

---

## Thumb Reach

Primary actions should stay reachable.

Examples:

* floating add button
* bottom navigation
* save buttons
* reveal/copy buttons

---

# 6. Navigation Rules

## Bottom Navigation

Primary navigation:

```text
Vault | Notes | Types | Settings
```

Do not add more than 4–5 root tabs.

---

## Navigation Philosophy

Navigation should feel:

* predictable
* shallow
* easy to memorize

Avoid:

* deep nested menus
* hidden gestures
* complicated routing

---

# 7. Notes & Documents Rules

## Notes Are First-Class

Notes are NOT secondary to passwords.

Nija stores:

* credentials
* cards
* identities
* rich secure documents

---

## Rich Notes Format

Use structured block model.

DO:

```json
{
  "type": "heading",
  "text": "Title"
}
```

DO NOT:

```html
<h1>Title</h1>
```

Never store raw HTML in vault payload.

---

## Supported Rich Blocks

Allowed MVP blocks:

* heading
* paragraph
* bullet
* checklist
* quote

Do not add:

* tables
* embeds
* code blocks
* collaborative editing
* markdown parsing

for MVP.

---

# 8. Security UX Rules

## Sensitive Data Visibility

Sensitive fields:

* hidden by default
* revealable individually
* copyable independently

---

## Clipboard Rules

Clipboard must:

* auto-clear after timeout
* show warning messaging

---

## Recovery Phrase Rules

Recovery phrase screens must:

* warn users clearly
* discourage screenshots
* encourage offline storage

---

## Biometric Rules

Biometric unlock is convenience only.

Master password remains primary authority.

---

# 9. Architecture Rules

## Architecture Style

Use:

# Modular Monolith

Do NOT use:

* microservices
* event overengineering
* distributed architecture
* backend-first systems

for MVP.

---

## Layering

Use:

```text
UI Layer
↓
Application Services
↓
Domain Models
↓
Infrastructure Adapters
```

---

## State Management

Preferred:

```text
Flutter + Riverpod
```

Avoid:

* global mutable state
* tightly coupled UI logic

---

## File Format Rules

Vault extension:

```text
.nija
```

Vault format must be:

* versioned
* portable
* documented
* future-readable

---

# 10. Security Architecture Rules

## Approved Crypto

Allowed:

* Argon2id
* XChaCha20-Poly1305
* AES-256-GCM

Disallowed:

* custom crypto
* homemade encryption
* weak KDFs

---

## Key Rules

Never:

* store master password
* store raw vault key
* store decrypted payload on disk
* log sensitive fields

---

## Encryption Model

Correct flow:

```text
Master Password
↓
Argon2id
↓
Password Key
↓
Decrypt Vault Key
↓
Decrypt Vault Payload
```

---

## Header Rules

Vault header is NOT secret.

Safe to store:

* Guardian profile
* KDF parameters
* salt
* nonce
* format version

Never depend on obscurity.

---

# 11. Coding Rules

## General Principles

Code must be:

* readable
* maintainable
* modular
* predictable
* testable

Avoid:

* clever abstractions
* unnecessary patterns
* deeply nested logic
* giant files

---

## Function Rules

Functions should:

* do one thing
* be easy to read
* avoid side effects where possible

Preferred:

```text
< 50 lines
```

---

## Component Rules

UI components should:

* be reusable
* be small
* avoid business logic

Business logic belongs in services.

---

## Naming Rules

Use clear names.

Good:

```text
VaultService
NoteService
unlockVault()
exportVault()
```

Bad:

```text
MagicManager
SuperHandler
MegaProcessor
```

---

## Comments

Comments should explain:

* WHY

not:

* WHAT obvious code does

---

## Error Handling

Errors should:

* fail safely
* never expose secrets
* never leak sensitive data

User-facing errors should be calm and understandable.

---

# 12. Testing Rules

Minimum required tests:

* vault parser
* crypto profile registry
* note block validation
* unlock flow
* item CRUD
* note CRUD
* route coverage

---

## Security Testing

Required:

* wrong password handling
* tampered vault handling
* corrupted file handling
* clipboard clearing
* auto-lock behavior

---

# 13. Product Boundaries

## Things We Explicitly Avoid

Nija should NOT become:

* social platform
* collaborative workspace
* AI assistant
* cloud-first SaaS
* bloated productivity suite

---

## MVP Constraints

MVP intentionally excludes:

* browser extension
* autofill
* team sharing
* passkeys
* attachments
* cloud sync engine
* real-time collaboration

---

# 14. Guardian Rules

Guardians are:

* UX abstractions
* crypto profile identities
* user-friendly protection levels

Guardians are NOT:

* secret keys
* authentication factors
* hidden encryption systems

---

## Current Guardians

### Owl

Balanced protection.

### Lion

Maximum protection.

### Falcon

Fast daily unlock.

---

# 15. Final Non-Negotiables

## Never:

* market as “unhackable”
* invent cryptography
* clutter the UI
* sacrifice readability for cleverness
* expose secrets in logs
* break local-first ownership
* overengineer MVP architecture
* make users dependent on company servers

---

## Always:

* prioritize trust
* prioritize simplicity
* prioritize ownership
* prioritize calm UX
* prioritize security transparency
* prioritize portability
* prioritize maintainability

---

# 16. Guiding Principle

Every design and engineering decision should answer:

> Does this help users safely own their private digital life with less friction?

If not, reconsider the decision.
