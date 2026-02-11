enum MarkdownSyntax {
  /// Standard markdown syntax.
  normal,

  /// Extended syntax which supports serialization of text alignment, strikethrough, underline and image size.
  ///
  /// Underline text is serialized between a pair of `¬`.
  ///
  /// Text alignment is serialized using an alignment notation at the
  /// line preceding the paragraph:
  ///
  /// `:---` represents left alignment. (The default)
  ///
  /// `:---:` represents center alignment.
  ///
  /// `---:` represents right alignment.
  ///
  /// `-::-` represents justify alignment.
  ///
  /// Image size is serialized using the notation `=widthxheight` after the url,
  /// separated by a space.
  superEditor,
}
