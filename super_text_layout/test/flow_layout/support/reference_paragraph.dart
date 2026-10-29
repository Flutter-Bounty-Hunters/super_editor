import 'package:flutter/widgets.dart';
import 'package:super_text_layout/experimental_flow.dart';

class ReferenceFlowParagraph extends FlowParagraph {
  const ReferenceFlowParagraph(
      {super.key,
      required super.controller,
      required super.children,
      super.style,
      super.regions,
      this.exhaustive = false});
  final bool exhaustive;
  @override
  RenderFlowParagraph createRenderObject(BuildContext context) =>
      super.createRenderObject(context)
        ..debugUseExhaustiveTextFitting = exhaustive;
  @override
  void updateRenderObject(
      BuildContext context, RenderFlowParagraph renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject.debugUseExhaustiveTextFitting = exhaustive;
  }
}
