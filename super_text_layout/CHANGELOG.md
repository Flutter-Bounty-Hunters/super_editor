## [0.1.20]
### Feb, 2026
* [FEATURE]: `SuperText` now supports `maxLines` and `overflow` effects. 

## [0.1.19]
### Apr, 2025
 * Improve right-to-left (RTL) text layout support.

## [0.1.18]
### Jan, 2024
 * Upgrade `attributed_text` dependency to `v0.4.1`.

## [0.1.17]
### Dec, 2024
 * Upgrade `attributed_text` dependency to `v0.4.0` (forgot to do it in `0.1.16`).

## [0.1.16]
### Dec, 2024
 * [FEATURE] - Added support for inline images. Only minor changes needed in this package.
   * Selection boxes now take up the `max` vertical space - this will result in taller selection boxes.
   * Caret size/position always uses a `downstream` affinity. This was done to minimize the impact of Flutter bugs for inline widgets.
   * A couple classes were created as inline image placeholders. Any type of object can be used, but providing a couple defaults seemed reasonable.
   * Most of the relevant changes for inline widgets will happen in `super_editor`.
 * [ADJUSTMENT] - Upgraded `logging` to `v1.3.0`.

## [0.1.15]
### Nov, 2024
 * [FIX] - Fix layout error when text in `SuperText` is empty.

## [0.1.14]
### Sept, 2024
 * [FIX] - Flutter was reporting 1px height different between empty text and non-empty text.
   We introduced a temporary hack fix to keep the reported height consistent until Flutter
   ships its own fix.

## [0.1.13]
### Sept, 2024
 * [FIX] - Caret size is as expected when placed at end of paragraph with preceding space. 
   This bug was caused by Flutter and we introduced a temporary hack to solve it until 
   Flutter ships its own fix.

## [0.1.12]
### Aug, 2024
 * Package metadata update - no functional changes.

## [0.1.11]
### Aug, 2024
 * [BREAKING] - Replaced singular `UnderlineStyle` in `TextUnderlineLayer` with a styler per 
   underline (to support composing, spelling errors, and grammar errors).
 * Text selection boxes now support rounded corners.
 * Adjusted the precise positioning of text selection rectangles.

## [0.1.10]
### June, 2024
 * `FillWidthIfConstrained` uses ancestor constraints instead of ancestor size.
 * Changed `getLineHeightAtPosition` and `getCharacterBox` to both use `RenderParagraph.getFullHeightForCaret()`.
 * Nudged the caret offset so that the caret straddles its desired location, instead of sitting completely to the right of it. 
 * Resolved some lint complaints.

## [0.1.9]
### Feb, 2024
 * [FIX] - `BlinkController.isBlinking` now accounts for the use of `Timer`s in addition to `Ticker`s.
 * [FIX] - Changing `textAlign` for `SuperText` correctly repositions carets, handles, and selection boxes for the newly aligned text.
 * [FIX] - `TextLayoutCaret` now respects the controller given to the widget, instead of ignoring it.
 * `TextLayout.getBoxesForSelection()` now allows you to choose between `tight` and `max` box sizes for each character box.
   * Related: underlines are now continuous instead of being broken between characters.

## [0.1.8]
### Dec, 2023
 * Added `TextUnderlineLayer` to draw underlines beneath text.
 * Added `collection` dependency.

## [0.1.7]
### July, 2023
 * Added `isBlinking` property to `BlinkController`.

## [0.1.6]
### May, 2023
 * Explicitly upgraded to Dart 3 support.
 * Bumped `attributed_text` dependency to `0.2.2`.

## [0.1.5]
### April, 2023
Added support for font scaling
 
 * Bumped `attributed_text` dependency to `0.2.1`.
 
## [0.1.4]
### Oct, 2022
Fixed a `NullPointerException` in `SuperTextLayout`

## [0.1.3]
### July, 2022
Upgraded the dependency on `attributed_text` from `0.1.3` to `0.2.0`

## [0.1.2]
### DEPRECATED - July, 2022
Upgraded the dependency on `attributed_text` from `0.1.3` to `0.2.0`

## [0.1.1]
### DEPRECATED - July, 2022
Added `estimatedLineHeight` to `TextLayout`. The method is experimental - it may be removed later

## [0.1.0]
### May, 2022
The `super_text_layout` package is extracted from `super_editor`

 * Introduces `SuperText` widget to render text with layers above and beneath the text
 * Introduces `SuperTextWithSelection` to easily paint text with traditional user selections, 
   which replaces previous uses of `SuperSelectableText` from earlier super_editor work
