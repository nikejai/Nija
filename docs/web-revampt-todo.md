# Web Revamp TODO

This tracker captures the WebApp/tablet revamp from the latest `Nija - E2E Responsive Wireframe` reference. Keep the current Nija theme and brand language. Use the wireframe for responsive structure, screen hierarchy, spacing, density, and interaction behavior.

Work through this file step by step. Each completed item should include focused code changes, tests, documentation updates, and a timestamped changelog entry.

## Source Wireframe Summary

- Mobile-first shell with native-feeling top bar, bottom navigation, centered floating add action, and fixed detail actions.
- Desktop shell at `>= 700px` with:
  - app grid: `76px` brand rail, `220px` vault navigation sidebar, main content.
  - larger shell at `>= 1100px`: `82px` rail, `238px` sidebar.
  - sticky desktop header about `68px` high.
  - main content width capped at about `1180px`.
  - narrow detail/form content capped at about `980px` where appropriate.
- General visual rules:
  - keep Nija's light/dark theme support.
  - use restrained surfaces, thin borders, low shadow, and consistent radius.
  - avoid full-browser stretching for reading, forms, details, and dialogs.
  - prefer compact workflow panels over large empty cards.

## Reference-To-Nija Mapping

| Reference surface | Nija route | Responsive target | Status |
| --- | --- | --- | --- |
| Product entry, vault picker, unlock | Onboarding and unlock flow | One mobile-first entry surface with a centered `460px` flow column at every width | Complete |
| Home dashboard | Vault tab | Compact mobile categories and bounded wide dashboard | In progress |
| All Items index | Types tab's All Items view | Mobile list; tablet/web index with bounded toolbar and columns | In progress |
| Item detail and document preview | Item/document detail routes | Mobile fixed actions; wide main/metadata split | In progress |
| Add/edit and type picker | Add-item and new-category routes | Mobile stacked form; constrained wide form/dialog | In progress |
| Favorites and settings | Favorites and Settings tabs | Same routes, bounded wide panels | In progress |
| Folders, templates, merge, trash | Folders are currently inferred from item metadata; other flows are contextual | Do not expose a folder-management action until the actual folder surface exists | Pending |

## Mobile-First Responsive Contract

- Mobile is the source layout. It keeps the top bar, bottom navigation, centered add action, bottom sheets, touch targets, and fixed detail actions.
- The rail/sidebar workspace is enabled only from `760px` when vertical room is at least `700px`; short landscape windows retain the compact mobile layout.
- Tablet/web adds bounded panels, denser rows, and desktop dialogs without changing Nija's current Vault, Types, Favorites, and Settings navigation.
- Mobile never receives desktop tables, persistent metadata panels, or desktop-only dialog presentation.

## Design Principles

- Preserve the Nija mobile theme so web, tablet, iOS, and Android feel like one product.
- Desktop/tablet must be designed as desktop/tablet, not a stretched mobile screen.
- Content should have a clear max reading width.
- Metadata must stay secondary to vault content.
- Show only meaningful fields; do not render empty labels.
- All existing user data must remain reachable, including 5+ folders/categories.
- Use contextual actions by screen and item type.
- Keep mobile behavior compact, touch-friendly, and app-like.
- Dialogs, sheets, and popovers should match the breakpoint.

## Current Problems To Eliminate

- Wide pages still have inconsistent density.
- Some pages use mobile patterns stretched across desktop widths.
- Dashboard category/folder cards can waste vertical space.
- Some lists and detail views compete with side metadata and actions.
- Dialogs can still feel like mobile sheets on desktop.
- Some flows route through outdated onboarding/unlock surfaces.
- Settings, templates, merge, trash, and secondary screens need deliberate desktop layouts.

## Target Responsive Shell

### Mobile

- Sticky top bar about `58px` high.
- Fixed bottom nav about `74px` high with five touch targets and centered add FAB.
- Main content padding roughly `18px 14px 110px`.
- Hide bottom nav on detail screens and bulk-selection mode.
- Detail screens use fixed bottom actions.
- Modal interactions use bottom sheets.

### Tablet And Desktop

- Use the desktop shell from `>= 760px` when the viewport height is at least `700px`.
- Shell layout:
  - brand rail: `76px`, then `82px` at larger widths.
  - vault sidebar: `220px`, then `238px` at larger widths.
  - main column: scrollable, constrained content.
- Content:
  - standard screens: max width about `1180px`.
  - narrow/detail/form screens: about `980px` to `1200px`, depending content.
- Desktop header is sticky and contains screen title plus contextual actions.
- Modal interactions use centered dialogs, anchored popovers, or side panels.

## Phase 1 - Entry, Unlock, And Vault Creation

- [x] Align the first page with the wireframe entry surface:
  - centered entry box, max width around `460-520px`.
  - four primary rows: `Open a vault`, `Create a vault`, `Continue recent`, `Import data`.
  - storage provider row for restore/import choices.
  - clear local-first notice without account language.
- [x] Ensure all entry actions route correctly:
- `Open a vault` -> vault picker/import file -> password sheet -> vault home.
  - `Create a vault` -> create-vault stepper -> recovery confirmation -> vault home.
  - `Continue recent` -> password sheet -> vault home.
- `Import data` -> import flow, not onboarding.

Implementation note: the entry surface follows the reference's four-row hierarchy as `Select a vault`, `Open vault file`, `Create a vault`, and `Import data`. `Select a vault`, wide dashboard `Switch vault`, and locking a vault open the same dedicated responsive known-vault page with saved-reference cards and one `Select different vault file` action; it is not a dialog or bottom sheet. The known-vault page now follows the reference selector scale directly: a centered `460px` shell, compact title rhythm, 86px vault rows, 42px icon blocks, and tight row spacing. Known-vault references retain only non-sensitive source hints such as browser private storage and selected file name; encrypted web vault bytes remain in browser private app storage, not HTTP cookies. Known-vault selection is separate from direct file import; cloud restore is one supported action, not unsupported provider placeholders.
- [ ] Implement responsive create-vault UX:
  - mobile: sheet.
  - desktop/tablet: centered dialog.
  - guardian/protection preset list.
  - vault name/password fields.
  - recovery phrase grid and confirmation.
- [ ] Add tests for the bad routes that previously regressed.

Acceptance criteria:
- No action unexpectedly opens the old onboarding/login surface.
- Creating or importing a vault opens the vault directly after successful password/confirmation.
- Entry page is not cropped at common desktop widths.

## Phase 2 - App Shell And Navigation

- [x] Make the web/tablet shell match the target rail + sidebar structure.
- [x] Keep mobile bottom navigation unchanged below the tablet breakpoint.
- [x] Add desktop sidebar sections:
  - active vault summary.
  - nav items: Home, All Items, Favorites, Settings.
  - switch-vault action pinned near the bottom when multi-vault switching is available; otherwise lock vault.
- [x] Add desktop rail:
  - brand mark.
  - theme toggle when theme changes are wired.
  - optional small vertical status label.
- [x] Add sticky desktop header with screen title and theme toggle.
- [ ] Add desktop sidebar folder shortcuts with counts.
- [ ] Make main content scroll normally without being cropped by fixed headers or sidebars.

Acceptance criteria:
- Desktop/tablet shows rail + sidebar.
- Mobile shows top bar + bottom nav.
- No viewport clips content at 768, 1024, 1280, 1440, or 1920 widths.

## Phase 3 - Dashboard Home

- [x] Replace oversized wide category/folder cards with compact wrapping tiles.
- [x] Remove hard caps that hide categories.
- [x] Implement desktop dashboard composition from the wireframe:
  - greeting/title row with `Add item`.
  - search row constrained to about `720px`.
  - six-card stats row: total items, folders, logins, notes, identities, documents.
  - stats row uses six columns on wide desktop and three columns on tablet.
  - main grid uses recent items on the left and quick actions on the right.
  - desktop grid ratio is roughly flexible main content plus a `300px` side column.
  - recent item rows use compact columns: type icon, title/subtitle, modified date, favorite/open affordance.
  - quick actions include `Add Item`, `Import`, and `Switch Vault`.
- [x] Implement mobile dashboard composition:
  - Nija brand/title block.
  - lock action in the brand row.
  - search row.
  - 2-column category grid.
  - category tiles for Notes, Logins, Identities, and Documents.
  - compact recent section with `View all`.
  - recent list shows the first few items only, then routes to All Items.
- [x] Dashboard navigation behavior:
  - clicking category tiles filters All Items by that category/type.
  - dashboard search clears stale All Items category/type/filter state before routing to search results.
  - `Add Item` opens the add-item flow.
  - `Import` opens import flow without onboarding.
  - `Switch Vault` returns to vault selection/unlock context.
- [x] All Items search coverage:
  - matches item title/subtitle.
  - matches type, folder, tags, note text, and structured field values.
- [x] Keep folder/category tiles compact and wrapping; do not stretch to full height.
- [x] Do not render categories with zero saved entries.
- [x] Add empty states for a new vault:
  - no large blank panels.
  - optional `View demo preview` action lets new users inspect sample dashboard content on Home only, without replacing real vault content in All Items, Favorites, or saved data.
  - clear `Add item`, `Import data`, and `Create note` actions.
- [ ] Add responsive tests for 0, 1, 5+, and 10+ categories/folders.
- [x] Add homepage-specific responsive tests:
  - mobile shows brand row, categories, and recent section.
  - desktop shows dashboard heading, six stats, recent panel, and quick-actions panel.
  - tablet collapses the desktop grid into one column when needed.

Acceptance criteria:
- All categories/folders are visible or scrollable.
- First desktop viewport shows useful vault content.
- Homepage actions route to the correct flows.
- No dashboard card has large unused vertical space for ordinary item counts.

## Phase 4 - All Items

- [x] Build a true desktop/tablet all-items index.
- [x] Keep the existing mobile list behavior.
- [x] Desktop row layout should roughly follow:
  - icon/select.
  - title/subtitle.
  - type/category.
  - folder.
  - modified/last accessed.
  - row actions.
- [x] Add compact toolbar:
  - search.
  - filter.
  - sort.
  - customize columns, if later needed.
  - add item.
- [x] Mobile all-items:
  - horizontal filter chips.
  - compact sort row.
  - touch-friendly item rows.
- [ ] Bulk mode:
  - selected count.
  - favorite/delete/share actions.
  - mobile bottom nav hidden while bulk mode is active.
  - desktop bulk bar near top of content, not full viewport width.

Acceptance criteria:
- Desktop all-items reads like a vault index, not a stretched mobile list.
- Multi-select works on both mobile and desktop.
- Search/filter/sort remain reachable at all breakpoints.

## Phase 5 - Item Detail

- [x] Constrain normal item detail layout.
- [x] Hide empty item fields.
- [x] Add type-aware primary actions.
- [ ] Bring all detail screens fully in line with the wireframe:
  - centered content frame.
  - item hero/title.
  - one field panel with thin separators.
  - optional copy/reveal controls per field.
  - desktop side panel for metadata and quick actions.
  - mobile collapsible metadata.
- [ ] Apply the same hierarchy to:
  - Login.
  - Password.
  - Identity.
  - Passport.
  - Driver License.
  - Card.
  - Bank Account.
  - Secure Note.
  - Document.
  - SSH Key.
- [ ] Attachments:
  - compact rows.
  - clear preview/open/download actions.
  - fullscreen/enlarge action for document previews.
  - no over-wide controls.
- [ ] Add tests for type-aware primary actions:
  - Login -> Copy password.
  - Password -> Copy password.
  - Identity -> Copy document number.
  - Passport -> Copy passport number.
  - Driver License -> Copy license number.
  - Card -> Copy card number.
  - Bank Account -> Copy account number.
  - Secure Note -> Copy note.
  - Document -> Open document.
  - SSH Key -> Copy public key.

Acceptance criteria:
- Details never span the full browser width.
- Metadata does not compete with secret/content values.
- Irrelevant actions, such as `Copy Password` for Identity, never appear.

## Phase 6 - Add/Edit Item And Type Picker

- [x] Convert wide add/edit screens into desktop forms:
  - main form area.
  - side helper/type details panel.
  - readable field widths.
- [x] Keep mobile add/edit behavior native and compact.
- [ ] Replace stretched category/type picker rows on web/tablet with compact grouped tiles or a constrained list.
- [ ] Keep save confirmation responsive:
  - desktop/tablet centered dialog.
  - mobile bottom sheet.
- [ ] Do not show empty optional fields after save.

Acceptance criteria:
- Add/edit feels like a desktop form on wide screens.
- Forms do not stretch field inputs across the viewport.
- Confirmation surfaces match the breakpoint.

## Phase 7 - Folders, Templates, Merge, Trash

- [ ] Folders:
  - mobile: 2-column folder cards or compact list.
  - desktop: 3-column grid or compact dashboard panel.
  - all folders visible or scrollable.
- [ ] Templates:
  - mobile stacked list.
  - desktop 3-column grid.
  - template fields previewed without excessive height.
- [ ] Vault Merge:
  - conflict cards.
  - current/imported version choices.
  - clear selected-version state.
- [ ] Trash:
  - compact rows.
  - restore/delete actions.
  - empty state.

Acceptance criteria:
- Secondary screens no longer feel like unfinished mobile pages on desktop.
- Counts, actions, and empty states are visible and understandable.

## Phase 8 - Settings And Operational Screens

- [x] Constrain settings width on web/tablet.
- [x] Group settings into panels:
  - vault.
  - security.
  - backup.
  - appearance/language.
  - import/export.
  - debug, when enabled.
- [x] Use setting rows with switches/menus where appropriate.
- [ ] Make backup controls read as an operational panel, not a long mobile list.
- [ ] Keep dangerous actions visually separated.

Acceptance criteria:
- Settings are scannable on desktop.
- Backup and security state are clear without crowding.

## Phase 9 - Responsive Modals, Sheets, And Toasts

- [x] Wide vault picker uses centered dialog.
- [x] Wide add-item saved confirmation uses centered dialog.
- [ ] Audit every bottom sheet in the vault shell.
- [ ] For each interaction choose:
  - mobile: bottom sheet.
  - tablet/desktop: centered dialog, popover, or side panel.
- [ ] Priority interactions:
- filters.
  - sort selectors.
  - quick actions.
  - delete confirmations.
  - language/theme pickers.
  - attachment actions.
  - encrypted share/export prompts.
- [ ] Toasts should be brief, non-blocking, and not hide mobile bottom actions.

Acceptance criteria:
- Desktop no longer shows mobile-style bottom sheets for primary workflows.
- Mobile keeps app-like bottom sheets where appropriate.

Completed in this pass: All Items filters use a centered dialog on tablet/web while mobile continues to use the full-screen compact filter surface.

## Phase 10 - Offline PWA And Release Readiness

- [ ] Confirm manifest and installability.
- [ ] Verify add-to-home-screen behavior:
  - iOS Safari.
  - Android Chrome.
  - desktop Chrome/Edge.
- [ ] Add offline app-shell messaging.
- [ ] Confirm encrypted vault data remains available offline after first load.
- [ ] Validate refresh/restart behavior for:
  - locked app.
  - unlocked app.
  - imported vault.
  - recent vault references.
- [ ] Add release checklist steps for WebApp `.webm` recordings and screenshots.

Acceptance criteria:
- Installed WebApp feels close to native for core vault workflows.
- Offline behavior is explicit and tested before release.

## Phase 11 - Security And Hardening

- [ ] Review web storage and service worker cache behavior.
- [ ] Ensure plaintext vault content is not cached in static assets or service worker caches.
- [ ] Add production security headers guidance to ops docs.
- [ ] Add platform hardening notes:
  - web minification.
  - web source-map policy.
  - web obfuscation limits.
  - Android obfuscation/symbol handling.
  - iOS symbol handling.
- [ ] Keep security states visible where useful:
  - local mode.
  - encrypted vault.
  - backup status.
  - lock/unlock context.

Acceptance criteria:
- Security posture is documented without fear-based messaging.
- Reverse-engineering hardening is tracked realistically per platform.

## Phase 12 - Visual QA Matrix

- [ ] Test every updated web screen in light and dark mode.
- [ ] Test breakpoints:
  - `390px` mobile.
  - `430px` mobile.
  - `768px` tablet portrait.
  - `1024px` tablet landscape.
  - `1280px` laptop.
  - `1440px` desktop.
  - `1920px` wide desktop.
- [ ] Check for:
  - text overflow.
  - clipped categories/folders.
  - unusable action buttons.
  - excessive empty card space.
  - mobile sheets on desktop.
  - content spanning too wide.
  - hidden scroll areas.
  - dialogs covering important context.

Acceptance criteria:
- Every target viewport has an intentional layout.
- No screen looks like an accidental stretch of another breakpoint.

## Implementation Order

1. Entry, unlock, and vault-creation routing.
2. App shell and navigation.
3. Dashboard home.
4. All Items.
5. Item detail.
6. Add/edit item and type picker.
7. Folders, templates, merge, and trash.
8. Settings and operational screens.
9. Responsive modal/sheet/toast audit.
10. Offline PWA and release readiness.
11. Security hardening.
12. Full visual QA pass.

## Definition Of Done For Each Step

- Code implemented with minimal scope.
- Relevant widget/integration tests added or updated.
- `flutter analyze` passes.
- Targeted tests pass.
- Web build passes when web behavior changed.
- `CHANGELOG.md` updated with timestamp.
- README/docs updated when behavior or process changes.
- Manual visual notes captured for any remaining follow-up.
