import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// A [ComponentBuilder] which builds an [ImageComponent] that always renders
/// images as a [SizedBox] with the given [size].
class FakeImageComponentBuilder implements ComponentBuilder {
  const FakeImageComponentBuilder({
    required this.size,
  });

  final Size size;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    return null;
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ImageComponentViewModel) {
      return null;
    }

    return ImageComponent(
      componentKey: componentContext.componentKey,
      imageUrl: componentViewModel.imageUrl,
      selection: componentViewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      imageBuilder: (context, imageUrl) => SizedBox(
        height: size.height,
        width: size.width,
      ),
    );
  }
}
