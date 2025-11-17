# Super Editor Quill
Extensions on Super Editor to support the Quill Deltas document format.

## DEPRECATED
Use `super_editor` directly, instead. We've moved all of this code into `super_editor`.

## What is Quill?
Quill is an open source JavaScript text editor created by Facebook.

https://quilljs.com/docs/quickstart

## What is the Quill Delta format?
Quill Delta is the name given to the data structure that describes a Quill document. In other words,
when a Quill editor loads a document, it's loading a document in the Quill Delta format. When a
Quill editor alters a document, the changes are expressed in the Quill Delta format.

The following is a tiny example of a Quill Delta document:

```json
{
  "ops": [
    { "insert": "Gandalf", "attributes": { "bold": true } },
    { "insert": " the " },
    { "insert": "Grey", "attributes": { "color": "#cccccc" } }
  ]
}
```

For more info on Quill Delta, see the official docs: https://quilljs.com/docs/delta/

## What is `super_editor_quill`?
The `super_editor_quill` package is a Flutter package that adds Quill Delta format support to the
`super_editor` package ([Super Editor on Pub](https://pub.dev/packages/super_editor)).

Supporting the Quill Delta format means that a `SuperEditor` document can be constructed from a
Quill Delta document. Also, a `SuperEditor` document can be serialized to a Quill Delta document.

Regardless of the incoming or outgoing document format, the actual editing pipeline within `SuperEditor`
remains the same. Thus, you could start a document from Markdown, and then export a document to
Quill Delta, or vis-a-versa. `SuperEditor` internals are format agnostic.

## References
 * Interactive Playground: https://v1.quilljs.com/playground/