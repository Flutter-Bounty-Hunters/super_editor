## [0.3.0-dev.42]
### Nov 26, 2025
* ADJUSTMENT: `MarkdownTableComponent`s now let you specify a column width policy, and a fit policy.
* FEATURE: Added a `GlobalScrollLock` to prevent two-dimensional scrolling with trackpad and Magic Mouse
  when the user expects only a single axis to scroll. E.g., scrolling a document vertically vs scrolling
  a table component horizontally.
  * Used by `SingleAxisTrackpadAndWheelScroller` to implement single-axis trackpad and scroll wheel scrolling.
  * Override your existing gesture-based scrollables with a `DeferToTrackpadsAndMouseWheelsScrollBehavior` to
    get them to defer to the `GlobalScrollLock`, too.

## [0.3.0-dev.41]
### Nov 24, 2025
* BREAKING: Centralized all `SuperEditor` IME connections. This change was made in an attempt to fix
            some non-reproducible issues where the IME keyboard would lose connection to a `SuperEditor`.
   * To upgrade to this version, you need to give each of your `SuperEditor` widgets a unique `inputRole`.
     The specific value of the `inputRole` doesn't matter, so long as different `SuperEditor`s in your app
     use different values.
* BREAKING: Moved all `super_editor_quill` code into `super_editor`. Will now
  deprecate `super_editor_quill` in favor of just using `super_editor`.
* FEATURE: Create a `SuperMessage` widget, which is an intrinsically sized document, like a
  `SuperReader` with intrinsic sizing and no scrolling. Made for chat use-cases.

## [0.3.0-dev.40]
### Nov 13, 2025
* BREAKING: Moved all `super_editor_markdown` code into `super_editor`. Will now
   deprecate `super_editor_markdown` in favor of just using `super_editor`.

## [0.3.0-dev.39]
### Nov 13, 2025
* FIX: `MessagePageScaffold` bottom sheet animation glitches fixed.
* ADJUSTMENT: `MessagePageScaffold` now has an optional maximum intrinsic height when 
   not in "expanded" mode.
* FIX: When an `Editable` or listener responding to an `Editable` can now immediately 
   submit `Editor` requests without blowing up.
* ADJUSTMENT: Don't require a `MutableDocument` or `MutableDocumentComposer` when calling
   `createDefaultEditor()`.
* FIX: Move remaining `OverlayController.show()` calls to post frame callbacks.

## [0.3.0-dev.38]
### Nov 9, 2025
* BREAKING, FIX: Rework `SuperEditorPlugin` lifecycle because we discovered that when
   one `SuperEditor` widget gets replaced by another, the new widget runs `initState()`
   before the old widget runs `dispose()`. This resulted in plugins ending up in a detached
   state when they should have been attached. This release adds some reference counting
   so that detachment only happens when it truly should.
* BREAKING, ADJUSTMENT: Related to the plugin lifecycle work, `EditContext.remove()` was
   adjusted to prevent accidentally removing a resource that was just added. The API change
   now expects you to pass the key to remove, and the value you want to remove for that key.
   If the current value doesn't match what is provided, then the removal doesn't happen.

## [0.3.0-dev.37]
### Nov 5, 2025
* ADJUSTMENT: Upgrade `super_keyboard` to `v0.3.0`.
* ADJUSTMENT: Upgrade `follow_the_leader` to `v0.5.2`.

## [0.3.0-dev.36]
### Oct 29, 2025
* ADJUSTMENT: Change Android toolbar to look like latest Android OS version.
* FIX: When loading a document that contains text with tag triggers, e.g. "/",
       don't attempt to compose tags when placing the caret near the trigger.

## [0.3.0-dev.35]
### Oct 7, 2025
* FIX: Detach plugins in `SuperEditor` `dispose()`.
* FIX: Crash when pushing route with `delegatedTransition`.

## [0.3.0-dev.34]
### Sept 23, 2025
* FIX: `MessagePageScaffold` fix its `Element` so that subtrees correctly activate and deactivate.
* FIX: `KeyboardPanelScaffold` under certain conditions retained toolbar space when toolbar wasn't visible.
* FIX: `KeyboardScaffoldSafeArea` handle possibility that the safe area content is below the bottom of the screen.
* FIX: A couple places where `OverlayController.show()` are called were moved to post frame callbacks.

## [0.3.0-dev.33]
### Aug 27, 2025
* ADJUSTMENT: Upgrade `attributed_text` dependency to `v0.4.5`. 

## [0.3.0-dev.32]
### Aug 27, 2025
* FIX: `HintTextComponent` now uses its given inline widget builders.

## [0.3.0-dev.31]
### Aug 26, 2025
* FEATURE: Block/Markdown Tables
   * Created a table node that holds styled text (no internal blocks), and supports upstream/downstream selection.
   * Parses a table node from Markdown, with super_editor_markdown 0.1.9.
   * Visual component for displaying Markdown tables.
* FIX: Placeholder bug when adding/removing attributions.
* FIX: No longer hides toolbar when releasing a long press in an editor.
* ADJUSTMENT: Publicly export ReadOnlyTaskComponentBuilder.

## [0.3.0-dev.30]
### Aug 26, 2025
Messed up release from wrong branch.

## [0.3.0-dev.29]
### July 27, 2025
 * FEATURE: Serialize `Document`s to HTML.

## [0.3.0-dev.28]
### July 22, 2025
 * FIX: Inserting character (via IME) with a block node and text selected, now correctly deletes the selected content
   before inserting the new character.

## [0.3.0-dev.27]
### July 10, 2025
Locked down the following versions to avoid unexpected Pub upgrades:
 * `follow_the_leader`: `v0.0.4.+8`
 * `overlord`: `v0.0.3+5`

## [0.3.0-dev.26]
### July 7, 2025
 * FEATURE: Custom underline configuration
 * FEATURE: Fade-In content for AI/GPT
 * BREAKING (Behavior): `SuperReader` shortcuts now run on a down-event instead of up-event

## [0.3.0-dev.25]
### June 6, 2025
 * FIX: Crash when connecting to IME (because Flutter broke everything with latest release).
 * ADJUSTMENT: Added a couple methods to the spelling and grammar plugin for working with spelling errors.

## [0.3.0-dev.24]
### May 26, 2025
 * FIX: Text is duplicated when typing with styles applied.
 * FIX: Ordered list item numerals are mis-aligned with content text.
 * FIX: Toolbar disappears after user presses "Select All", preventing selection of "copy" or "paste".
 * ADJUSTMENT: Add option to bypass `MediaQuery` and user `super_keyboard` to monitor keyboard
   height in a `KeyboardPanelScaffold`. This was added to work around a possible `MediaQuery`
   glitch on Android due to an app mishandling the Android lifecycle/permission requirements.
 * FIX: Editor overlays obscure everything below them when using Dev Tools with layout outlines.

## [0.3.0-dev.23]
### Apr 3, 2025
 * FIX: iOS native toolbar "select all" now selects all document content instead of just the paragraph.
 * FIX: Pressing `enter` to split list items works again.
 * ADJUSTMENT: Prevent Flutter's invalidation of widget span layout just because the widget
   changes - instead we delegate to Flutter's standard render object layout invalidation mechanism.

## [0.3.0-dev.22]
### Mar 28, 2025
 * FIX: `MessagePageScaffold` - Prevent possible negative layout constraints on bottom sheet.

## [0.3.0-dev.21]
### Mar 27, 2025
 * FEATURE: Chat - Added a `MessagePageScaffold` to create chat pages with a bottom mounted editor.
 * FEATURE: List items support inline widgets.
 * FIX: Super Reader - Crash when rotating phone with an expanded selection.

## [0.3.0-dev.20]
### Mar 7, 2025
 * FIX: Keyboard safe area rare layout exception due to dirty ancestor layout.

## [0.3.0-dev.19]
### Feb 11, 2025
 * FIX: Immutability error in the spelling and grammar styler.
 * ADJUSTMENT: Upgrade to `attributed_text` `v0.4.4` (with some fixes to inline placeholders).

## [0.3.0-dev.18]
### Jan 30, 2025
 * ADJUSTMENT: Upgrade to `attributed_text` `v0.4.3` (with fixes to per-character lookup).

## [0.3.0-dev.17]
### Jan 28, 2025
 * FEATURE: Inline widgets for `SuperTextField`.
 * FIX: `SuperEditor`: Selecting text with inline widgets and toggling styles deleted the inline widgets.
 * FIX: Caret place wrong with RTL languages.
 * FIX: Crash when selecting in an empty paragraph with a selection color strategy.
 * FIX: Backspace to un-indent on Web.
 * ADJUSTMENT: Tasks are rendered by default in `SuperReader`.

## [0.3.0-dev.16]
### Jan 24, 2025
 * FIX: `KeyboardScaffoldSafeArea` in rare circumstances was trying to use `NaN` for bottom insets.
 * FIX: On Safari/Firefox, double tapping on text closing the IME connection.

## [0.3.0-dev.15]
### Jan 17, 2025
 * FEATURE: Spellcheck for mobile (when using the `super_editor_spellcheck` plugin).
 * ADJUSTMENT: Upgrade to `attributed_text` `v0.4.2` (with some fixes to inline placeholders).

## [0.3.0-dev.14]
### Jan 14, 2025
 * FIX: `KeyboardScaffoldSafeArea` breaks and defers to `MediaQuery` when there's only one in the tree.

## [0.3.0-dev.13]
### Jan 10, 2025
 * BREAKING: All `DocumentNode`s are now immutable. To change a node, it must be copied and replaced.
 * BREAKING: Newline insertion behavior is now configurable.
   * All newlines are inserted with explicit `EditRequest`s, e.g., `InsertNewlineRequest`, `InsertSoftNewlineRequest`.
   * The signature for mapping from `EditRequest` to `EditCommand` was adjusted.
   * Some `EditRequest`s no longer support `const` construction.
 * FIX: Make `KeyboardScaffoldSafeArea` work when not positioned at bottom of screen.
 * FIX: Crash in tags plugin related to selection.
 * FIX: Selection highlight issue with `SuperTextField`.
 * FIX: Magnifier doesn't move offscreen.
 * ADJUSTMENT: Email links launch with a "mailto:" scheme, and app links are linkified.
 * ADJUSTMENT: Apps can override tap gestures.
 * ADJUSTMENT: iOS tap word snapping is less aggressive.
 * ADJUSTMENT: Upgraded `attributed_text` dependency to `v0.4.1`.

## [0.3.0-dev.12]
### Dec 23, 2024
 * FEATURE: Added support for inline widgets.
 * FEATURE: Created a `ClearDocumentRequest`, which deletes all content and moves caret to the start.
 * FIX: Web - option + arrow selection changes.
 * FIX: `SuperTextField` (iOS) - native content menu focal point was wrong.
 * FIX: Action tag not identified and triggered in expected situations.
 * ADJUSTMENT: `KeyboardPanelScaffold` supports opening a panel before opening the software keyboard.
 * ADJUSTMENT: `getDocumentPositionAfterExpandedDeletion` returns `null` for collapsed selections.
 * ADJUSTMENT: `TaskNode` checkbox sets visual density based on `ThemeData.visualDensity`.

## [0.3.0-dev.11]
### Nov 26, 2024
 * FEATURE: Add an (optional) tap handler that automatically inserts empty paragraph
   when user taps at the end of the document.
 * FIX: `KeyboardScaffoldSafeArea` now initializes its insets in a way that works with
   certain navigation use-cases that previously thought the keyboard was up when it's down.
 * FIX: Honor the Android handle builders in the Android controls controller.
 * ADJUSTMENT: Upgraded versions for a number of dependencies.

## [0.3.0-dev.10]
### Nov 18, 2024
 * FEATURE: Created `KeyboardPanelScaffold` and `KeyboardScaffoldSafeArea` to aid with
   implementing mobile phone messaging and chat experiences.
 * FEATURE: Added ability to show the iOS native context popover toolbar when
   editing a document. See `iOSSystemPopoverEditorToolbarWithFallbackBuilder`
   and `IOSSystemContextMenu`.
 * FEATURE: Plugins can now provide their own `ComponentBuilder`s.
 * FEATURE: Can configure block nodes as "non-deletable".
 * FIX: CMD + RIGHT caret movement on Web.
 * FIX: Don't restore editor selection on refocus if document changed in way that
   invalidates the previous selection.
 * FIX: `shrinkWrap` as `true` no longer breaks `SuperEditor`.
 * ADJUSTMENT: Remove custom gesture handlers in `SuperEditor` and `SuperReader`
   and utilize Flutter's built-in behaviors.

## [0.3.0-dev.9]
### Sept 26, 2024
 * FEATURE: Indent for blockquotes.

## [0.3.0-dev.8]
### Sept 24, 2024
 * ADJUSTMENT: Change mobile caret overlays to use `Timer`s instead of `Ticker`s
   to prevent frame churn.

## [0.3.0-dev.7]
### Sept 24, 2024
 * ADJUSTMENT: Change `super_text_layout` dependency from v0.1.13 to v0.1.14.

## [0.3.0-dev.6]
### Sept 15, 2024
 * FIX: Don't cut off iOS drag handles in `SuperEditor`.
 * ADJUSTMENT: Increase iOS drag handle interaction area in `SuperTextField`.

## [0.3.0-dev.5]
### Aug 27, 2024
 * FEATURE: Add configurable underlines to `TextWithHintComponent`.
 * ADJUSTMENT: Increase the types of attributions that are automatically extended when typing immediately after those attributions.
 * ADJUSTMENT: Convert floating cursor geometry to document coordinates.
 * FIX: Retain desired composing attributions when collapsing an expanded selection.
 * FIX: (Android) auto-scroll when selection changes.

## [0.3.0-dev.4]
### Aug 17, 2024
 * Package metadata update - no functional changes.

## [0.3.0-dev.3]
### Aug 16, 2024
 * DEPENDENCY: Upgraded `super_text_layout` to `v0.1.11`.
 * BREAKING: Remove `nodes` list from `Document` API in preparation for immutable `Document`s.
 * BREAKING: When inserting new nodes, make copies of the provided nodes instead of
   retaining the original node, so that undo/redo can restore the original state.
 * FEATURE: Undo/redo (partial implementation, off by default).
 * FEATURE: Can apply arbitrary underline decorations to text in documents.
 * ADJUSTMENT: Deprecated `document` and `composer` properties of `SuperEditor` - they're not read
   directly from the `Editor`.
 * ADJUSTMENT: Added extension methods on `Editor` to access `document` and `composer` directly.
 * ADJUSTMENT: Selection-by-word on Android.
 * ADJUSTMENT: Mobile text selection handle appearance.
 * ADJUSTMENT: Dragging to change selection on Android plays haptic feedback.
 * FIX: Crash on long press over non-text node.
 * FIX: Caret was blinking while being dragged (should stop blinking).
 * FIX: Crash when merging paragraphs (Mac).
 * FIX: Exception thrown when pressing ESC while composing an action tag.
 * FIX: Vertical scrolling on multi-line `SuperTextField` now works.
 * FIX: List item component styles are respected when the stylesheet doesn't specify 
   list item styles.
 * FIX: Horizontal drag and editor scrolling.

## [0.3.0-dev.2]
### July 2, 2024
 * DEPENDENCY: Upgraded `attributed_text` to `v0.3.2`.
 * FEATURE: Tasks can now be indented.
 * FEATURE: Can convert a paragraph to a task.
 * FIX: Tasks can be created in the "completed" state.
 * FEATURE: Added attributions for font family, superscript, and subscript.
 * ADJUSTMENT: (iOS) - place caret at word boundary on tap.
 * ADJUSTMENT: (Android) - increased touch area for selection handles.
 * FEATURE: Automatic linkification for Markdown as the user types.
 * FIX: Crash in linkification reaction.
 * FIX: Crash in `SelectedTextColorStrategy`.

## [0.3.0-dev.1]
### June 10, 2024
MAJOR UPDATE: First taste of the new editor pipeline. 

This is a dev release so that you can begin to see the changes coming in the next major version. 
This release comes with numerous and significant breaking changes. As we get closer to stability 
for the next release, we'll add website guides to help update all of our users. 

The primary features that we've been working on since last release include:
 * Undo/Redo
 * A stable edit pipeline: requests > commands > change list > reactions > listeners
 * Common reaction features, e.g., hash tags and user tagging

In addition to the major feature work, we've made hundreds of little adjustments, including bugfixes.

We expect a steady stream of dev releases from this point forward, until we reach `v0.3.0`.

## [0.2.6]
### May 28, 2023
 * FEATURE: `SuperReader` now launches URLs when tapping a link (#1151)
 * FIX: `SuperEditor` now correctly handles "\n" newlines reported by Android IME deltas (#1086)

## [0.2.6-dev.1]
### May 28, 2023
* The same as v0.2.6+1, but compatible with Flutter `master`

## [0.2.5]
### May 12, 2023:
 * Add support for Dart 3 and Flutter 3.10

## [0.2.4-dev.1]
### May 08, 2023: 
 * The same as v0.2.4+1, but compatible with Flutter `master`

## [0.2.4]
### May 08, 2023:
 * FEATURE: `SuperEditor` includes a built-in concept of a "task"
 * FEATURE: `SuperEditor` links open on tap, when in "interaction mode"
 * FEATURE: `SuperEditor`, `SuperReader`, `SuperTextField` all respect `MediaQuery` text scale
 * FEATURE: `SuperEditor` selection changes now include a "reason", to facilitate multi-user and server interactions
 * FEATURE: `SuperEditor` supports GBoard spacebar caret movement, and other software keyboard gestures
 * FEATURE: `SuperEditor` allows a selection even when the software keyboard is closed, and also lets apps open and close the keyboard at their discretion
 * FEATURE: `SuperEditor` lets apps override what happens when the IME wants to a perform an action, like "done" or "newline"
 * FEATURE: `SuperEditor` respects inherited `MediaQuery` `GestureSetting`s
 * FEATURE: `SuperTextField` now exposes configuration for the caret style
 * FEATURE: `SuperTextField` now exposes configuration for keyboard appearance
 * FEATURE: `SuperDesktopTextField` now supports IME text entry, which adds support for compound characters
 * FIX: `SuperEditor` don't scroll while dragging over an image
 * FIX: `SuperEditor` partial improvements to iOS floating cursor display
 * FIX: `SuperEditor` fix text styles when backspacing a list item into a preceding paragraph
 * FIX: `SuperEditor` rebuilds layers when document layout or component layout changes, e.g., rebuilds caret when a list item animates its size
 * FIX: `SuperTextField` when selection changes, don't auto-scroll if the new selection position is already visible
 * FIX: `SuperTextField` popup toolbar on iOS shows the arrow pointing towards content, instead of pointing away from content
 * FIX: `SuperTextField` don't change selection when two fingers move on trackpad
 * FIX: `SuperTextField` handle numpad ENTER same as regular ENTER
 * FIX: `SuperTextField` when user taps to stop scroll momentum, don't change the selection

## [0.2.3-dev.1]
### Nov 11, 2022: SuperReader, Bug Fixes (pre-release)
 * The same as v0.2.3+1, but compatible with Flutter `master`

## [0.2.3+1]
### Nov, 2022: Pub.dev listing updates
 * No functional changes

## [0.2.3]
### Nov, 2022: SuperReader, Bug Fixes
 * FEATURE: SuperReader - Created a `SuperReader` for read-only documents (0424ff1c6695629d2dba8214a950d261a3002b02)
 * FEATURE: SuperEditor - Simulate IME text input for tests (3b67328722288d9c31ac52bed1bce4a550868e58)
 * FEATURE: SuperEditor - linkify pasted text (397e373c3f53844b7b7e644c6dccbe7a7c02b822)
 * FEATURE: SuperTextField - Add padding property (2437d84735556cd4aaa30c61f413eefe7c51bbcb)
 * FEATURE: SuperEditor - Align text with stylesheet rules (23fb39aa0aecdd611106f5d7d75bbfbeb0e0ce5a)
 * FIX: SuperEditor - scrolling a document that sits in a horizontal list view (f8aec2e84782f4976f26e14880770611337b8e82)
 * FIX: SuperTextField - scrolling behavior when `maxLines` is `null` (f31fe207538aea76ef78242810ff85850b4cda63)
 * FIX: SuperEditor - scroll jumping when typing near the top/bottom editor boundary (c2485223059f84f52a7cdb5de62a7a9ca00fe32c)
 * FIX: SuperTextField - horizontal alignment (6704f8e1ab4c6e4fdf46e73daf6e5f58b897e23f)
 * FIX: SuperTextField - Remove focus when detached from IME on iOS (5f0d921d885068da408359def576b021ba6aa151)
 * FIX: SuperTextField - Hint text cut off on desktop (d1214e97d0c255b9ab2c5cb6d9b3ead40aced0c9)
 * FIX: SuperEditor - set selection when editor receives focus (c866122e52b22c995630d673c2af8258722e04ec)
 * FIX: SuperEditor - Caret display when editor receives focus (ecc0af2e4380be9d8250f51f1f75fbdb780a3432)
 * FIX: SuperTextField - Exception during hot reload on desktop (4ae59142ae4c7e5e2e151683ff7bc941505b366f)
 * FIX: SuperTextField - Bad line height estimation on Mac (16fa1e993907bf06cd10abca853ddcb57d46212d)
 * FIX: SuperEditor - Ignore pointer events on block quote so selection works (700f0f752f9b0ac2ee05ea10e79edf97f114c26c)
 * FIX: SuperEditor - Serialization and deserialization of empty paragraphs (1601fdce95ebfa34bddf80cab3e58e700b0edec3)
 * FIX: SuperEditor - Caret placement when indenting a list item (595a5704f4ebabfb0a90ee2568591af28ecbf96c)
 * FIX: SuperEditor - Trackpad scrolling due to Flutter change (f4d342c161432f3ccf94c72d251f72eb1ae58754)
 * FIX: SuperEditor - Image scrolling with mouse wheel (874df02ad2759a0c2615e4f3521bda3d6e261c31)
 * FIX: SuperEditor - List indentation using TAB key (f1570ec515218cd525c4c7e5d41d39373ccab210)
 * FIX: SuperEditor - Selection when tapping beyond end of document (d5e7460956fc6d60abd65991d48ca2c073c1da38)
 * FIX: SuperEditor - Crash when changing gesture mode (b9f868766767756ad589984d74089ef780809b95)
 * FIX: SuperEditor - Respect `TextAffinity` for selection (0c50b67f5ef4e0e8d4ee0fc9a7e625d84c5027db)
 * FIX: SuperEditor - Default gesture mode (63bb2f283efd4e773bd86651709bdc11d1614547)
 * FIX: SuperEditor - List item style when converting to paragraph and back again (7db7fcd84e8fc3715448eda6d7ec9cc754c29f0b)
 * FIX: SuperTextField - Viewport height when text changes on mobile (376c0b6856f217b7364ee81cad41140f7132a570)
 * FIX: SuperEditor - Desktop scroll momentum that was broken by Flutter 3.3.3 (f7f20b93cb0d86246f501e20d871806df6140b5d)
 * FIX: SuperEditor - Floating cursor opacity (dec4bd3076efffe5f795bf88f8d7dbffbe94732f)
 * FIX: SuperEditor - Typing lag in large documents (ae571decde5884fd246f858754dfc71b4e4fabc5)


## [0.2.2]
### July, 2022: Desktop IME
 * Use the input method engine (IME) on Desktop (previously only available on mobile)
 * A number of `SuperTextField` fixes and improvements. These changes are part of the path to the next release, which is focused on stabilizing `SuperTextField`.

## [0.2.1]
### ~July, 2022: Desktop IME~ (Removed from pub)
 * Use the input method engine (IME) on Desktop (previously only available on mobile)
 * A number of `SuperTextField` fixes and improvements. These changes are part of the path to the next release, which is focused on stabilizing `SuperTextField`.

## [0.2.0]
### Feb, 2022: Mobile Support
 * Mobile document editing
 * Mobile text field editing
 * More document style controls

## [0.1.0]
### June 3, 2021

The first release of Super Editor.

 * Document and editor abstractions
   * See `Document` for a readable document
   * See `MutableDocument` for a mutable document
   * See `DocumentEditor` to commit document changes in a transactional manner
   * See `DocumentSelection` for a logical representation of selected document content
   * See `DocumentLayout` for the base abstraction for a visual document layout
 * Out-of-the-box editor: Commonly used types of content, visual layout, and user interactions are supported
   by artifacts available in the `default_editor` package.
 * Markdown serialization is available in the `serialization` package.
 * SuperTextField: An early version of a custom text field called `SuperTextField` is available in
   the `infrastructure` package.
 * SuperSelectableText: All text display in Super Editor is based on the `SuperSelectableText` widget,
   which is available in the `infrastructure` package.
 * AttributedText: a logical representation of text with attributed spans is available
   in the `infrastructure` package.
 * AttributedSpans: a logical representation of attributed spans is available in the
   `infrastructure` package.
