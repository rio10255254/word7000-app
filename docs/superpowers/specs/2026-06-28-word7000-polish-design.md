# Word7000 Polish Design

## Goal

Adopt the "A. refined stable" direction: keep Word7000 clean and fast, while making the app feel complete through consistent icons, a short launch animation, folded filters, quiz filters, and light in-app motion.

## Scope

- Replace the app icon set with a consistent W7 visual identity for installed web app, browser favicon, Expo icon, Android adaptive icon, and splash icon.
- Add a short in-app launch overlay that appears briefly after the app shell loads and then fades away.
- Fold Library level and letter filters behind a compact filter panel, while keeping the main status chips and search easy to reach.
- Add matching filters to Quiz so users can test a specific status, level, and first letter.
- Add light transitions for tab changes, filter panels, cards, quiz answers, and launch state.

## UX Rules

- Motion should be quiet and quick, not decorative.
- The first screen remains the actual app, not a landing page.
- Filter controls should reduce clutter on mobile but still make current choices visible.
- Quiz must never ask from the wrong filtered set. If no words match, show a clear empty state instead of crashing.
- Existing account and local progress behavior must stay unchanged.

## Verification

- Unit tests confirm quiz filtering and fallback behavior.
- Build verifies the web export and PWA metadata.
- Mobile-size browser checks cover launch, folded filters, quiz filters, and basic navigation.
