import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// A globally shared holder of an IME connection, so that the IME connection
/// can be seamlessly transferred between the same `SuperEditor` or `SuperTextField`
/// when their tree is rebuilt.
class SuperIme with ChangeNotifier {
  static SuperIme? _instance;
  static SuperIme get instance {
    _instance ??= SuperIme._();
    return _instance!;
  }

  SuperIme._();

  SuperImeInputId? _owner;
  TextInputConnection? _imeConnection;

  /// Returns `true` if [SuperIme] currently holds a Flutter [TextInputConnection]
  /// in [imeConnection].
  ///
  /// The existence of an [imeConnection] doesn't mean that connection is attached to
  /// the operating system. To check that status, use [isAttachedToOS].
  bool get hasConnection => _imeConnection != null;

  /// Returns `true` if [SuperIme] currently holds a Flutter [TextInputConnection]
  /// AND that connection is attached to the operating system.
  ///
  /// When this is `true`, the operating system software keyboard, or other IME
  /// interface, is currently interacting with the app (e.g., inputting text).
  bool get isAttachedToOS => _imeConnection?.attached ?? false;

  /// Returns `true` if the given [input] is the current owner of the shared IME,
  /// and the shared IME is currently attached to the OS.
  bool isInputAttachedToOS(SuperImeInputId input) => _owner == input && isAttachedToOS;

  /// If [owner] is the current IME owner, returns the shared [TextInputConnection], or `null` if
  /// no such connection currently exists, or if the [owner] isn't actually the owner.
  TextInputConnection? getImeConnectionForOwner(SuperImeInputId owner) {
    if (owner != _owner) {
      return null;
    }

    return _imeConnection;
  }

  /// If the given [ownerInputId] is the current owner, opens a new [TextInputConnection], and
  /// optionally shows the software keyboard.
  ///
  /// The opened IME connection is available via [getImeConnectionForOwner].
  void openConnection(
    SuperImeInputId ownerInputId,
    TextInputClient client,
    TextInputConfiguration configuration, {
    bool showKeyboard = false,
  }) {
    if (!isOwner(ownerInputId)) {
      return;
    }

    if (false == _imeConnection?.attached) {
      // We have a connection, but its been detached, and we can't re-attach
      // without creating a new connection. Throw it away.
      //
      // While SuperIme might be a global, shared IME, we don't actually have
      // global control of the IME. Only Flutter does. We need to be resilient to
      // any other Flutter input messing with the IME.
      _imeConnection = null;
    }

    _imeConnection ??= TextInput.attach(client, configuration);
    if (showKeyboard) {
      _imeConnection!.show();
    }

    notifyListeners();
  }

  /// If the given [ownerInputId] is the current owner, then the current input connection
  /// is closed, and the connection null'ed out.
  void clearConnection(SuperImeInputId ownerInputId) {
    if (!isOwner(ownerInputId)) {
      return;
    }

    _imeConnection?.close();
    _imeConnection = null;

    notifyListeners();
  }

  /// Returns `true` if a [SuperImeInputId] has claimed ownership of the shared IME.
  ///
  /// The existence of an owner doesn't imply the existence of an [imeConnection]. It's the
  /// owner's job to open and close [imeConnection]s, as needed.
  bool get isOwned => _owner != null;

  /// Returns true if the given [inputId] is the current owner of the shared IME.
  bool isOwner(SuperImeInputId? inputId) => _owner == inputId;

  /// Takes ownership of the shared IME.
  ///
  /// Ownership might be taken from another owner, or might be taken at a moment where no
  /// other owner exists. Taking ownership doesn't open or close an existing IME connection,
  /// it only changes the actor that's allowed to open and access the IME connection.
  ///
  /// One owner cannot prevent another owner from taking ownership. This mechanism is not
  /// a security feature, it's a convenience feature for different areas of code to work
  /// together around the fact that only a single IME connection exists per app.
  void takeOwnership(SuperImeInputId newOwnerInputId) {
    if (_owner == newOwnerInputId) {
      return;
    }

    _owner = newOwnerInputId;

    notifyListeners();
  }

  /// Releases ownership of the IME, if [ownerInputId] is the current owner.
  ///
  /// We take an [ownerInputId] to reduce the possibility that one IME input accidentally
  /// releases ownership when they're not the owner.
  ///
  /// For convenience, this method closes the open connection upon release, and then
  /// throws away the connection, forcing the next owner to create a new connection,
  /// and then open it. To prevent this, pass `false` for [clearConnectionOnRelease].
  void releaseOwnership(
    SuperImeInputId ownerInputId, {
    bool clearConnectionOnRelease = true,
  }) {
    if (_owner != ownerInputId) {
      return;
    }

    if (clearConnectionOnRelease) {
      clearConnection(ownerInputId);
    }
    _owner = null;

    notifyListeners();
  }
}

/// A specific IME input that might want to own the [SuperIme] shared IME.
///
/// This class is just a composite ID, which is registered with [SuperIme] to
/// claim ownership over the IME. See [role] and [instance] for their individual
/// meaning.
class SuperImeInputId {
  SuperImeInputId({
    required this.role,
    required this.instance,
  });

  /// The role this owner is playing in the UI, or `null` if there's only a single
  /// input widget in the whole widget tree.
  ///
  /// It's fine to provide a [role] even if there's only one input in the widget tree.
  ///
  /// Examples of possible [role] values include things like "chat", "document", "journal", or
  /// any other type of content that an input might exist to compose. This choice is up
  /// to the developer and the only thing that matters is uniqueness, e.g., "chat" is different
  /// from "journal".
  ///
  /// ### How `role` works
  /// The [role] is critical for dealing with `State` disposal and recreation when a
  /// widget tree changes an ancestor, and therefore recreates the entire subtree.
  ///
  /// For example, imagine a widget tree like this:
  ///
  /// ```dart
  /// SuperEditor(
  ///   //...
  /// )
  /// ```
  ///
  /// Then, something causes the widget tree to add a `SizedBox` above the `SuperEditor`:
  ///
  /// ```dart
  /// SizedBox(
  ///   child: SuperEditor(
  ///     //...
  ///   ),
  /// );
  /// ```
  ///
  /// This change causes the `SuperEditor` and all of its internal widgets to be disposed
  /// and recreated. More specifically, for each widget in the subtree, a new widget is
  /// initialized, and the previous widget is then disposed.
  ///
  /// But these widgets don't have any idea that they're being replaced - as far as they know
  /// they're being permanently destroyed. So should `SuperEditor`'s IME connection be closed
  /// or not?
  ///
  /// This [role] is an ID that binds together the previous `SuperEditor` that's disposed
  /// with the new `SuperEditor` that's being created. It tells the disposing `SuperEditor`
  /// NOT to close its IME connection, so that the new `SuperEditor` can continue to use it.
  /// This sharing prevents unexpected raising of the software keyboard across subtree
  /// recreations.
  final String? role;

  /// The specific owner of the IME, even within the same [role].
  ///
  /// The purpose of [instance] is to differentiate between initializing widgets and
  /// disposing widgets for the same input. See [role] for more info.
  ///
  /// A typical choice to provide as the [instance] is the [State] object that
  /// owns a given IME connection. This is a naturally effective choice because the
  /// concept of the [instance] is typically used to differentiate between initializing
  /// and disposing [State] objects for the same widget.
  final Object instance;

  @override
  String toString() => "${role ?? 'Global editor'} ($instance)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperImeInputId && runtimeType == other.runtimeType && role == other.role && instance == other.instance;

  @override
  int get hashCode => role.hashCode ^ instance.hashCode;
}
