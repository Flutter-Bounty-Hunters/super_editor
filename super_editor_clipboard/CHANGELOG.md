## [0.2.5]
### Jan 28, 2026
* Expose public method for native clipboard pasting into `Editor`: `pasteIntoEditorFromNativeClipboard`.

## [0.2.4]
### Jan 26, 2026
* iOS: Added swizzling to Flutter's iOS delegate that answers the question "is there content to paste?".
       We did this because Flutter only says "yes" when there's text data on the clipboard, but we
       also want to support binary pasting.

## [0.2.3]
### Jan 19, 2026
* **CHANGED PACKAGE TO A PLUGIN**
* iOS: Created plugin that swizzles Flutter's paste behavior and lets your app handle native toolbar pasting.

## [0.2.2]
### Dec 13, 2025
* FEATURE: Rich text paste (from HTML)
* DEPENDENCY CHANGES:
  * Upgraded `super_editor` to `0.3.0-dev.46`

## [0.2.1]
### Dec 8, 2025
* DEPENDENCY CHANGES:
  * Upgraded `super_editor` to `0.3.0-dev.44`

## [0.2.0]
### Nov 25, 2025
* DEPENDENCY CHANGES:
  * Removed dependency on `super_editor_markdown` in favor of just `super_editor`
  * Upgraded `super_editor` to `0.3.0-dev.41`

## [0.1.3]
### Aug 27, 2025
* ADJUSTMENT: Upgraded `super_editor` dependency to `^0.3.0-dev.33`.

## [0.1.2]
### Aug 27, 2025
* ADJUSTMENT: Upgraded `super_editor` dependency to `0.3.0-dev.32`.

## [0.1.1]
### Aug 27, 2025
 * ADJUSTMENT: Upgraded `super_editor_markdown` dependency to `^0.1.1`.

## [0.1.0]
### July 27, 2025
Initial release:
 * [SuperEditor] keyboard shortcuts that copy rich text to the clipboard.
 * [SuperReader] keyboard shortcuts that copy rich text to the clipboard.
 * Extension on [Document] that serializes it to HTML.
