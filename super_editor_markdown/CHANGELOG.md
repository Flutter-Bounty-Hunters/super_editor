## [0.2.0]
### Aug 27, 2025
* ADJUSTMENT: Inline Markdown parsing is now configurable with a couple properties added to the document parser.

## [0.1.9]
### Aug 26, 2025
* FEATURE: Added table parsing.
* FIX: Parsing a list item followed by a task.

## [0.1.8]
### June, 2025
* Update `super_editor` dependency to `v0.3.0-dev.25`.

## [0.1.7]
### Jan, 2025
* Update `super_editor` dependency to `v0.3.0-dev.13`.
* Update `markdown` dependency to `v7.2.1`.
* Update `logging` dependency to `v1.3.0`.

## [0.1.6]
### Aug, 2024
* Update `super_editor` dependency to `v0.3.0-dev.3`.
* Update package metadata.

## [0.1.5]
### May, 2023
* Added explicit support for Dart 3
* Bumped `super_editor` dependency to `v0.2.5`

## [0.1.4+2]
### May, 2023
* Added support for paragraph "justify" alignment in Markdown serialization.

## [0.1.4+1]
### Nov, 2022
* Added support for custom Markdown block syntax.
* Fix: parsing empty markdown into a document.
* Fix: serialization of paragraph alignment, text strikethrough and underline.

## [0.1.4]
### Nov, 2022
* De-listed because we forgot to upgrade the super_editor dependency

## [0.1.3]
### July, 2022
* Updated `AttributedText` serialization to use new `AttributionVisitor` API.

## [0.1.2]
### ~July, 2022~ (Removed from pub)
* Updated `AttributedText` serialization to use new `AttributionVisitor` API.

## [0.1.1]
### June, 2022
* BREAKING: changed super_editor_markdown to NOT append newlines after every line it serializes to avoid extra newlines at the end of a serialized document.