## [0.1.0-dev.11]
### Nov 15, 2025
**FINAL RELEASE:** This release is an announcement that we've moved all the code from
this package into `super_editor`. Please use `super_editor` instead.

## 0.1.0-dev.10
* Adjustment: Make it possible to serialize text inline placeholders as inline embeds.
* Fix: Exception when serializing an empty document.

## 0.1.0-dev.9
* Adjustment: Parsing deltas now allow for configurable merging of consecutive blocks, e.g., lines of code.

## 0.1.0-dev.8
* Update `super_editor` to `v0.3.0-dev.13`.
* Update `logging` to `v1.3.0`.

## 0.1.0-dev.7
* Feature: Customizable block-level embed parsers.

## 0.1.0-dev.6
* Adjustment: A custom `Editor` can now be supplied when parsing deltas.

## 0.1.0-dev.5
* Feature: Customizable inline embed parsers and serializers.

## 0.1.0-dev.4
* Fix: Avoid throwing an exception when using ambiguous custom delta formats.

## 0.1.0-dev.3
* Switch `super_editor` dependency from GitHub version to pre-release version `0.3.0-dev.3`.

## 0.1.0-dev.2
* Expose Quill Delta document matcher so others can write tests with it.

## 0.1.0-dev.1
Initial pre-release:

* Parse a Quill Delta document to a Super Editor `MutableDocument`.
* Serialize a Super Editor `MutableDocument` to a Quill Delta document.
