## [0.3.0]
### Nov 4, 2025
 * BREAKING: Moved logging to a class called `SKLog`, made log printer configurable by client apps.
 * BREAKING: Adjusted platform logging so that platform logs can (optionally) be forwarded to the Flutter-side logger.

## [0.2.2]
### July 6, 2025
 * FEATURE: `KeyboardHeightSimulator` can now render a widget version of a software keyboard in golden tests.
 * ADJUSTMENT: Added an option for `KeyboardPanelScaffold` to bypass Flutter's `MediaQuery`.

## [0.2.1]
### May 26, 2025
 * FIX: Fix keyboard test simulator - we accidentally hard coded the keyboard height in a few places, now it respects
   the desired keyboard height.

## [0.2.0]
### May 26, 2025
 * BREAKING: Keyboard state and height are now reported together as a "geometry" data structure.
 * ADJUSTMENT: Android - Bottom padding is now reported along with keyboard height and state.

## [0.1.1]
### Mar 27, 2025
 * FIX: Android - Only listen for keyboard changes between `onResume` and `onPause`.
 * FIX: Android - Report closed keyboard upon `onResume` in case it closed after switching the app.
 * ADJUSTMENT: Flutter + Platforms - Make logging controllable.

## [0.1.0]
### Dec 22, 2024
Initial release:
 * iOS: Reports keyboard closed, opening, open, and closing. No keyboard height.
 * Android: Reports keyboard closed, opening, open, and closing, as well as keyboard height.
