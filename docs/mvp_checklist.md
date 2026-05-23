# MVP Checklist (Execution Snapshot)

## Design and UX

- Mobile-first widths with centered constrained canvas.
- Calm, minimal UI with soft contrast and rounded cards/buttons.
- Bottom navigation with `Vault | Notes | Types | Settings`.

## Security and Vault

- `.nija` vault file schema model implemented.
- Guardian profile based KDF/cipher metadata mapping implemented.
- Create/unlock service flow implemented in app service layer.
- Auto-lock on app background/inactive implemented.
- Sensitive-field copy path uses clipboard auto-clear timer.

## Vault and Notes Experience

- Dashboard with search + recent items.
- Item detail with per-field reveal/hide and copy.
- Add/edit-style flows for items (modal add flow).
- Notes section with structured blocks and note detail rendering.
- Empty states for item/note lists.

## Settings and Backup UX

- Security setting for biometric unlock.
- Backup/export placeholder entry.
- Screenshot protection hardening marked as platform-specific placeholder.

## Validation

- `flutter analyze` clean.
- Unit tests added for vault file, vault service roundtrip, and validators.
- Widget tests added for onboarding flow and app shell tab presence.
