// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'framework.dart';

export 'package:flutter/services.dart' show AutofillHints;

/// Predefined autofill context clean up actions.
enum AutofillContextAction {
  /// Destroys the current autofill context after informing the platform to save
  /// the user input from it.
  ///
  /// Corresponds to calling [TextInput.finishAutofillContext] with
  /// `shouldSave == true`.
  commit,

  /// Destroys the current autofill context without saving the user input.
  ///
  /// Corresponds to calling [TextInput.finishAutofillContext] with
  /// `shouldSave == false`.
  cancel,
}

/// An [AutofillScope] widget that groups [AutofillClient]s together.
///
/// [AutofillClient]s that share the same closest [AutofillGroup] ancestor must
/// be built together, and they be will be autofilled together.
///
/// {@macro flutter.services.AutofillScope}
///
/// The [AutofillGroup] widget only knows about [AutofillClient]s registered to
/// it using the [AutofillGroupState.register] API. Typically, [AutofillGroup]
/// will not pick up [AutofillClient]s that are not mounted, for example, an
/// [AutofillClient] within a [Scrollable] that has never been scrolled into the
/// viewport. To workaround this problem, ensure clients in the same
/// [AutofillGroup] are built together.
///
/// The topmost [AutofillGroup] widgets (the ones that are closest to the root
/// widget) can be used to clean up the current autofill context when the
/// current autofill context is no longer relevant.
///
/// {@macro flutter.services.TextInput.finishAutofillContext}
///
/// By default, [onDisposeAction] is set to [AutofillContextAction.commit], in
/// which case when any of the topmost [AutofillGroup]s is being disposed, the
/// platform will be informed to save the user input from the current autofill
/// context, then the current autofill context will be destroyed, to free
/// resources. You can, for example, wrap a route that contains a [Form] full of
/// autofillable input fields in an [AutofillGroup], so the user input of the
/// [Form] can be saved for future autofill by the platform.
///
/// {@tool dartpad}
/// An example form with autofillable fields grouped into different
/// `AutofillGroup`s.
///
/// ** See code in examples/api/lib/widgets/autofill/autofill_group.0.dart **
/// {@end-tool}
///
/// See also:
///
/// * [AutofillContextAction], an enum that contains predefined autofill context
///   clean up actions to be run when a topmost [AutofillGroup] is disposed.
class AutofillGroup extends StatefulWidget {
  /// Creates a scope for autofillable input fields.
  ///
  /// The [child] argument must not be null.
  const AutofillGroup({
    Key? key,
    required this.child,
    this.onDisposeAction = AutofillContextAction.commit,
  }) : assert(child != null),
       super(key: key);

  /// Returns the closest [AutofillGroupState] which encloses the given context.
  ///
  /// {@macro flutter.widgets.AutofillGroupState}
  ///
  /// See also:
  ///
  /// * [EditableTextState], where this method is used to retrieve the closest
  ///   [AutofillGroupState].
  static AutofillGroupState? of(BuildContext context) {
    final _AutofillScope? scope = context.dependOnInheritedWidgetOfExactType<_AutofillScope>();
    return scope?._scope;
  }

  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// The [AutofillContextAction] to be run when this [AutofillGroup] is the
  /// topmost [AutofillGroup] and it's being disposed, in order to clean up the
  /// current autofill context.
  ///
  /// {@macro flutter.services.TextInput.finishAutofillContext}
  ///
  /// Defaults to [AutofillContextAction.commit], which prompts the platform to
  /// save the user input and destroy the current autofill context.
  final AutofillContextAction onDisposeAction;

  @override
  AutofillGroupState createState() => AutofillGroupState();
}

/// State associated with an [AutofillGroup] widget.
///
/// {@template flutter.widgets.AutofillGroupState}
/// An [AutofillGroupState] can be used to register an [AutofillClient] when it
/// enters this [AutofillGroup] (for example, when an [EditableText] is mounted or
/// reparented onto the [AutofillGroup]'s subtree), and unregister an
/// [AutofillClient] when it exits (for example, when an [EditableText] gets
/// unmounted or reparented out of the [AutofillGroup]'s subtree).
///
/// The [AutofillGroupState] class also provides an [AutofillGroupState.attach]
/// method that can be called by [TextInputClient]s that support autofill,
/// instead of [TextInput.attach], to create a [TextInputConnection] to interact
/// with the platform's text input system.
/// {@endtemplate}
///
/// Typically obtained using [AutofillGroup.of].
class AutofillGroupState extends State<AutofillGroup> with AutofillScopeMixin {
  final Map<String, AutofillClient> _clients = <String, AutofillClient>{};

  // Whether this AutofillGroup widget is the topmost AutofillGroup (i.e., it
  // has no AutofillGroup ancestor). Each topmost AutofillGroup runs its
  // `AutofillGroup.onDisposeAction` when it gets disposed.
  bool _isTopmostAutofillGroup = false;

  @override
  AutofillClient? getAutofillClient(String autofillId) => _clients[autofillId];

  @override
  Iterable<AutofillClient> get autofillClients {
    return _clients.values
      .where((AutofillClient client) => client.textInputConfiguration.autofillConfiguration.enabled);
  }

  /// Adds the [AutofillClient] to this [AutofillGroup].
  ///
  /// Typically, this is called by [TextInputClient]s that support autofill (for
  /// example, [EditableTextState]) in [State.didChangeDependencies], when the
  /// input field should be registered to a new [AutofillGroup].
  ///
  /// See also:
  ///
  /// * [EditableTextState.didChangeDependencies], where this method is called
  ///   to update the current [AutofillScope] when needed.
  void register(AutofillClient client) {
    assert(client != null);
    _clients.putIfAbsent(client.autofillId, () => client);
  }

  /// Removes an [AutofillClient] with the given `autofillId` from this
  /// [AutofillGroup].
  ///
  /// Typically, this should be called by a text field when it's being disposed,
  /// or before it's registered with a different [AutofillGroup].
  ///
  /// See also:
  ///
  /// * [EditableTextState.didChangeDependencies], where this method is called
  ///   to unregister from the previous [AutofillScope].
  /// * [EditableTextState.dispose], where this method is called to unregister
  ///   from the current [AutofillScope] when the widget is about to be removed
  ///   from the tree.
  void unregister(String autofillId) {
    assert(autofillId != null && _clients.containsKey(autofillId));
    _clients.remove(autofillId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isTopmostAutofillGroup = AutofillGroup.of(context) == null;
  }

  @override
  Widget build(BuildContext context) {
    return _AutofillScope(
      autofillScopeState: this,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    super.dispose();

    if (!_isTopmostAutofillGroup || widget.onDisposeAction == null)
      return;
    switch (widget.onDisposeAction) {
      case AutofillContextAction.cancel:
        TextInput.finishAutofillContext(shouldSave: false);
        break;
      case AutofillContextAction.commit:
        TextInput.finishAutofillContext();
        break;
    }
  }
}

class _AutofillScope extends InheritedWidget {
  const _AutofillScope({
    Key? key,
    required Widget child,
    AutofillGroupState? autofillScopeState,
  }) : _scope = autofillScopeState,
       super(key: key, child: child);

  final AutofillGroupState? _scope;

  AutofillGroup get client => _scope!.widget;

  @override
  bool updateShouldNotify(_AutofillScope old) => _scope != old._scope;
}
