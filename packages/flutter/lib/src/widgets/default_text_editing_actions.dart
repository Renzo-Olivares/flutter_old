// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'actions.dart';
import 'focus_traversal.dart';
import 'framework.dart';
import 'text_editing_intents.dart';

class DefaultTextEditingActions extends StatelessWidget {
  const DefaultTextEditingActions({required this.child, required this.delegate, super.key});

  final Widget child;

  final TextSelectionDelegate delegate;

  // --------------------------- Text Editing Actions ---------------------------

  TextBoundary _characterBoundary(DirectionalTextEditingIntent intent) {
    final TextBoundary atomicTextBoundary = widget.obscureText ? _CodeUnitBoundary(delegate.textEditingValue.text) : CharacterBoundary(delegate.textEditingValue.text);
    return intent.forward ? PushTextPosition.forward + atomicTextBoundary : PushTextPosition.backward + atomicTextBoundary;
  }

  TextBoundary _nextWordBoundary(DirectionalTextEditingIntent intent) {
    final TextBoundary atomicTextBoundary;
    final TextBoundary boundary;

    if (widget.obscureText) {
      atomicTextBoundary = _CodeUnitBoundary(delegate.textEditingValue.text);
      boundary = DocumentBoundary(delegate.textEditingValue.text);
    } else {
      final TextEditingValue textEditingValue = _textEditingValueforTextLayoutMetrics;
      atomicTextBoundary = CharacterBoundary(textEditingValue.text);
      // This isn't enough. Newline characters.
      boundary = WhitespaceBoundary(textEditingValue.text) + WordBoundary(renderEditable);
    }

    final _MixedBoundary mixedBoundary = intent.forward
      ? _MixedBoundary(atomicTextBoundary, boundary)
      : _MixedBoundary(boundary, atomicTextBoundary);
    // Use a _MixedBoundary to make sure we don't leave invalid codepoints in
    // the field after deletion.
    return intent.forward ? PushTextPosition.forward + mixedBoundary : PushTextPosition.backward + mixedBoundary;
  }

  TextBoundary _linebreak(DirectionalTextEditingIntent intent) {
    final TextBoundary atomicTextBoundary;
    final TextBoundary boundary;

    if (widget.obscureText) {
      atomicTextBoundary = _CodeUnitBoundary(delegate.textEditingValue.text);
      boundary = DocumentBoundary(delegate.textEditingValue.text);
    } else {
      final TextEditingValue textEditingValue = _textEditingValueforTextLayoutMetrics;
      atomicTextBoundary = CharacterBoundary(textEditingValue.text);
      boundary = LineBreak(renderEditable);
    }

    // The _MixedBoundary is to make sure we don't leave invalid code units in
    // the field after deletion.
    // `boundary` doesn't need to be wrapped in a _CollapsedSelectionBoundary,
    // since the document boundary is unique and the linebreak boundary is
    // already caret-location based.
    final TextBoundary pushed = intent.forward
      ? PushTextPosition.forward + atomicTextBoundary
      : PushTextPosition.backward + atomicTextBoundary;
    return intent.forward ? _MixedBoundary(pushed, boundary) : _MixedBoundary(boundary, pushed);
  }

  TextBoundary _documentBoundary(DirectionalTextEditingIntent intent) => DocumentBoundary(delegate.textEditingValue.text);

  Action<T> _makeOverridable<T extends Intent>(Action<T> defaultAction) {
    return Action<T>.overridable(context: context, defaultAction: defaultAction);
  }

  /// Transpose the characters immediately before and after the current
  /// collapsed selection.
  ///
  /// When the cursor is at the end of the text, transposes the last two
  /// characters, if they exist.
  ///
  /// When the cursor is at the start of the text, does nothing.
  void _transposeCharacters(TransposeCharactersIntent intent) {
    if (delegate.textEditingValue.text.characters.length <= 1
        || delegate.textEditingValue.selection == null
        || !delegate.textEditingValue.selection.isCollapsed
        || delegate.textEditingValue.selection.baseOffset == 0) {
      return;
    }

    final String text = delegate.textEditingValue.text;
    final TextSelection selection = delegate.textEditingValue.selection;
    final bool atEnd = selection.baseOffset == text.length;
    final CharacterRange transposing = CharacterRange.at(text, selection.baseOffset);
    if (atEnd) {
      transposing.moveBack(2);
    } else {
      transposing..moveBack()..expandNext();
    }
    assert(transposing.currentCharacters.length == 2);

    delegate.userUpdateTextEditingValue(
      TextEditingValue(
        text: transposing.stringBefore
            + transposing.currentCharacters.last
            + transposing.currentCharacters.first
            + transposing.stringAfter,
        selection: TextSelection.collapsed(
          offset: transposing.stringBeforeLength + transposing.current.length,
        ),
      ),
      SelectionChangedCause.keyboard,
    );
  }
  late final Action<TransposeCharactersIntent> _transposeCharactersAction = CallbackAction<TransposeCharactersIntent>(onInvoke: _transposeCharacters);

  void _replaceText(ReplaceTextIntent intent) {
    final TextEditingValue oldValue = delegate.textEditingValue;
    final TextEditingValue newValue = intent.currentTextEditingValue.replaced(
      intent.replacementRange,
      intent.replacementText,
    );
    delegate.userUpdateTextEditingValue(newValue, intent.cause);

    // If there's no change in text and selection (e.g. when selecting and
    // pasting identical text), the widget won't be rebuilt on value update.
    // Handle this by calling _didChangeTextEditingValue() so caret and scroll
    // updates can happen.
    if (newValue == oldValue) {
      _didChangeTextEditingValue();
    }
  }
  late final Action<ReplaceTextIntent> _replaceTextAction = CallbackAction<ReplaceTextIntent>(onInvoke: _replaceText);

  // Scrolls either to the beginning or end of the document depending on the
  // intent's `forward` parameter.
  void _scrollToDocumentBoundary(ScrollToDocumentBoundaryIntent intent) {
    if (intent.forward) {
      delegate.bringIntoView(TextPosition(offset: delegate.textEditingValue.text.length));
    } else {
      delegate.bringIntoView(const TextPosition(offset: 0));
    }
  }

  void _updateSelection(UpdateSelectionIntent intent) {
    delegate.bringIntoView(intent.newSelection.extent);
    delegate.userUpdateTextEditingValue(
      intent.currentTextEditingValue.copyWith(selection: intent.newSelection),
      intent.cause,
    );
  }
  late final Action<UpdateSelectionIntent> _updateSelectionAction = CallbackAction<UpdateSelectionIntent>(onInvoke: _updateSelection);

  late final _UpdateTextSelectionToAdjacentLineAction<ExtendSelectionVerticallyToAdjacentLineIntent> _adjacentLineAction = _UpdateTextSelectionToAdjacentLineAction<ExtendSelectionVerticallyToAdjacentLineIntent>(this);

  void _expandSelectionToDocumentBoundary(ExpandSelectionToDocumentBoundaryIntent intent) {
    final TextBoundary textBoundary = _documentBoundary(intent);
    _expandSelection(intent.forward, textBoundary, true);
  }

  void _expandSelectionToLinebreak(ExpandSelectionToLineBreakIntent intent) {
    final TextBoundary textBoundary = _linebreak(intent);
    _expandSelection(intent.forward, textBoundary);
  }

  void _expandSelection(bool forward, TextBoundary textBoundary, [bool extentAtIndex = false]) {
    final TextSelection textBoundarySelection = delegate.textEditingValue.selection;
    if (!textBoundarySelection.isValid) {
      return;
    }

    final bool inOrder = textBoundarySelection.baseOffset <= textBoundarySelection.extentOffset;
    final bool towardsExtent = forward == inOrder;
    final TextPosition position = towardsExtent
        ? textBoundarySelection.extent
        : textBoundarySelection.base;

    final TextPosition newExtent = forward
      ? textBoundary.getTrailingTextBoundaryAt(position)
      : textBoundary.getLeadingTextBoundaryAt(position);

    final TextSelection newSelection = textBoundarySelection.expandTo(newExtent, textBoundarySelection.isCollapsed || extentAtIndex);
    delegate.userUpdateTextEditingValue(
      delegate.textEditingValue.copyWith(selection: newSelection),
      SelectionChangedCause.keyboard,
    );
    delegate.bringIntoView(newSelection.extent);
  }

  Object? _hideToolbarIfVisible(DismissIntent intent) {
    if (_selectionOverlay?.toolbarIsVisible ?? false) {
      hideToolbar(false);
      return null;
    }
    return Actions.invoke(context, intent);
  }

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    DoNothingAndStopPropagationTextIntent: DoNothingAction(consumesKey: false),
    ReplaceTextIntent: _replaceTextAction,
    UpdateSelectionIntent: _updateSelectionAction,
    DirectionalFocusIntent: DirectionalFocusAction.forTextField(),
    DismissIntent: CallbackAction<DismissIntent>(onInvoke: _hideToolbarIfVisible),

    // Delete
    DeleteCharacterIntent: _makeOverridable(_DeleteTextAction<DeleteCharacterIntent>(this, _characterBoundary)),
    DeleteToNextWordBoundaryIntent: _makeOverridable(_DeleteTextAction<DeleteToNextWordBoundaryIntent>(this, _nextWordBoundary)),
    DeleteToLineBreakIntent: _makeOverridable(_DeleteTextAction<DeleteToLineBreakIntent>(this, _linebreak)),

    // Extend/Move Selection
    ExtendSelectionByCharacterIntent: _makeOverridable(_UpdateTextSelectionAction<ExtendSelectionByCharacterIntent>(this, false, _characterBoundary)),
    ExtendSelectionToNextWordBoundaryIntent: _makeOverridable(_UpdateTextSelectionAction<ExtendSelectionToNextWordBoundaryIntent>(this, true, _nextWordBoundary)),
    ExtendSelectionToLineBreakIntent: _makeOverridable(_UpdateTextSelectionAction<ExtendSelectionToLineBreakIntent>(this, true, _linebreak)),
    ExpandSelectionToLineBreakIntent: _makeOverridable(CallbackAction<ExpandSelectionToLineBreakIntent>(onInvoke: _expandSelectionToLinebreak)),
    ExpandSelectionToDocumentBoundaryIntent: _makeOverridable(CallbackAction<ExpandSelectionToDocumentBoundaryIntent>(onInvoke: _expandSelectionToDocumentBoundary)),
    ExtendSelectionVerticallyToAdjacentLineIntent: _makeOverridable(_adjacentLineAction),
    ExtendSelectionToDocumentBoundaryIntent: _makeOverridable(_UpdateTextSelectionAction<ExtendSelectionToDocumentBoundaryIntent>(this, true, _documentBoundary)),
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent: _makeOverridable(_ExtendSelectionOrCaretPositionAction(this, _nextWordBoundary)),
    ScrollToDocumentBoundaryIntent: _makeOverridable(CallbackAction<ScrollToDocumentBoundaryIntent>(onInvoke: _scrollToDocumentBoundary)),

    // Copy Paste
    SelectAllTextIntent: _makeOverridable(_SelectAllAction(this)),
    CopySelectionTextIntent: _makeOverridable(_CopySelectionAction(this)),
    PasteTextIntent: _makeOverridable(CallbackAction<PasteTextIntent>(onInvoke: (PasteTextIntent intent) => pasteText(intent.cause))),

    TransposeCharactersIntent: _makeOverridable(_transposeCharactersAction),
  };

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: _actions,
      child: child,
    );
  }
}

/// A text boundary that uses code units as logical boundaries.
///
/// This text boundary treats every character in input string as an utf-16 code
/// unit. This can be useful when handling text without any grapheme cluster,
/// e.g. the obscure string in [EditableText]. If you are handling text that may
/// include grapheme clusters, consider using [CharacterBoundary].
class _CodeUnitBoundary extends TextBoundary {
  const _CodeUnitBoundary(this._text);

  final String _text;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    if (position.offset <= 0) {
      return const TextPosition(offset: 0);
    }
    if (position.offset > _text.length ||
        (position.offset == _text.length && position.affinity == TextAffinity.downstream)) {
      return TextPosition(offset: _text.length, affinity: TextAffinity.upstream);
    }
    switch (position.affinity) {
      case TextAffinity.upstream:
        return TextPosition(offset: math.min(position.offset - 1, _text.length));
      case TextAffinity.downstream:
        return TextPosition(offset: math.min(position.offset, _text.length));
    }
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    if (position.offset < 0 ||
        (position.offset == 0 && position.affinity == TextAffinity.upstream)) {
      return const TextPosition(offset: 0);
    }
    if (position.offset >= _text.length) {
      return TextPosition(offset: _text.length, affinity: TextAffinity.upstream);
    }
    switch (position.affinity) {
      case TextAffinity.upstream:
        return TextPosition(offset: math.min(position.offset, _text.length), affinity: TextAffinity.upstream);
      case TextAffinity.downstream:
        return TextPosition(offset: math.min(position.offset + 1, _text.length), affinity: TextAffinity.upstream);
    }
  }
}

// ------------------------  Text Boundary Combinators ------------------------

// A _TextBoundary that creates a [TextRange] where its start is from the
// specified leading text boundary and its end is from the specified trailing
// text boundary.
class _MixedBoundary extends TextBoundary {
  _MixedBoundary(
    this.leadingTextBoundary,
    this.trailingTextBoundary
  );

  final TextBoundary leadingTextBoundary;
  final TextBoundary trailingTextBoundary;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) => leadingTextBoundary.getLeadingTextBoundaryAt(position);

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) => trailingTextBoundary.getTrailingTextBoundaryAt(position);
}

// -------------------------------  Text Actions -------------------------------
class _DeleteTextAction<T extends DirectionalTextEditingIntent> extends ContextAction<T> {
  _DeleteTextAction(this.delegate, this.getTextBoundariesForIntent);

  final TextSelectionDelegate delegate;
  final TextBoundary Function(T intent) getTextBoundariesForIntent;

  TextRange _expandNonCollapsedRange(TextEditingValue value) {
    final TextRange selection = value.selection;
    assert(selection.isValid);
    assert(!selection.isCollapsed);
    final TextBoundary atomicBoundary = state.widget.obscureText
      ? _CodeUnitBoundary(value.text)
      : CharacterBoundary(value.text);

    return TextRange(
      start: atomicBoundary.getLeadingTextBoundaryAt(TextPosition(offset: selection.start)).offset,
      end: atomicBoundary.getTrailingTextBoundaryAt(TextPosition(offset: selection.end - 1)).offset,
    );
  }

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    final TextSelection selection = delegate.textEditingValue.selection;
    assert(selection.isValid);

    if (!selection.isCollapsed) {
      return Actions.invoke(
        context!,
        ReplaceTextIntent(delegate.textEditingValue, '', _expandNonCollapsedRange(delegate.textEditingValue), SelectionChangedCause.keyboard),
      );
    }

    final TextBoundary textBoundary = getTextBoundariesForIntent(intent);
    if (!delegate.textEditingValue.selection.isValid) {
      return null;
    }
    if (!delegate.textEditingValue.selection.isCollapsed) {
      return Actions.invoke(
        context!,
        ReplaceTextIntent(delegate.textEditingValue, '', _expandNonCollapsedRange(delegate.textEditingValue), SelectionChangedCause.keyboard),
      );
    }

    return Actions.invoke(
      context!,
      ReplaceTextIntent(
        delegate.textEditingValue,
        '',
        textBoundary.getTextBoundaryAt(delegate.textEditingValue.selection.base),
        SelectionChangedCause.keyboard,
      ),
    );
  }

  @override
  bool get isActionEnabled => !state.widget.readOnly && delegate.textEditingValue.selection.isValid;
}

class _UpdateTextSelectionAction<T extends DirectionalCaretMovementIntent> extends ContextAction<T> {
  _UpdateTextSelectionAction(
    this.delegate,
    this.ignoreNonCollapsedSelection,
    this.getTextBoundariesForIntent,
  );

  final TextSelectionDelegate delegate;
  final bool ignoreNonCollapsedSelection;
  final TextBoundary Function(T intent) getTextBoundariesForIntent;

  static const int NEWLINE_CODE_UNIT = 10;

  // Returns true iff the given position is at a wordwrap boundary in the
  // upstream position.
  bool _isAtWordwrapUpstream(TextPosition position) {
    final TextPosition end = TextPosition(
      offset: state.renderEditable.getLineAtOffset(position).end,
      affinity: TextAffinity.upstream,
    );
    return end == position && end.offset != delegate.textEditingValue.text.length
        && delegate.textEditingValue.text.codeUnitAt(position.offset) != NEWLINE_CODE_UNIT;
  }

  // Returns true if the given position at a wordwrap boundary in the
  // downstream position.
  bool _isAtWordwrapDownstream(TextPosition position) {
    final TextPosition start = TextPosition(
      offset: state.renderEditable.getLineAtOffset(position).start,
    );
    return start == position && start.offset != 0
        && delegate.textEditingValue.text.codeUnitAt(position.offset - 1) != NEWLINE_CODE_UNIT;
  }

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    final TextSelection selection = delegate.textEditingValue.selection;
    assert(selection.isValid);

    final bool collapseSelection = intent.collapseSelection || !state.widget.selectionEnabled;
    // Collapse to the logical start/end.
    TextSelection collapse(TextSelection selection) {
      assert(selection.isValid);
      assert(!selection.isCollapsed);
      return selection.copyWith(
        baseOffset: intent.forward ? selection.end : selection.start,
        extentOffset: intent.forward ? selection.end : selection.start,
      );
    }

    if (!selection.isCollapsed && !ignoreNonCollapsedSelection && collapseSelection) {
      return Actions.invoke(
        context!,
        UpdateSelectionIntent(delegate.textEditingValue, collapse(selection), SelectionChangedCause.keyboard),
      );
    }

    final TextBoundary textBoundary = getTextBoundariesForIntent(intent);

    TextPosition extent = selection.extent;
    // If continuesAtWrap is true extent and is at the relevant wordwrap, then
    // move it just to the other side of the wordwrap.
    if (intent.continuesAtWrap) {
      if (intent.forward && _isAtWordwrapUpstream(extent)) {
        extent = TextPosition(
          offset: extent.offset,
        );
      } else if (!intent.forward && _isAtWordwrapDownstream(extent)) {
        extent = TextPosition(
          offset: extent.offset,
          affinity: TextAffinity.upstream,
        );
      }
    }

    final TextPosition newExtent = intent.forward
      ? textBoundary.getTrailingTextBoundaryAt(extent)
      : textBoundary.getLeadingTextBoundaryAt(extent);
    final TextSelection newSelection = collapseSelection
      ? TextSelection.fromPosition(newExtent)
      : selection.extendTo(newExtent);

    // If collapseAtReversal is true and would have an effect, collapse it.
    if (!selection.isCollapsed && intent.collapseAtReversal
        && (selection.baseOffset < selection.extentOffset !=
        newSelection.baseOffset < newSelection.extentOffset)) {
      return Actions.invoke(
        context!,
        UpdateSelectionIntent(
          delegate.textEditingValue,
          TextSelection.fromPosition(selection.base),
          SelectionChangedCause.keyboard,
        ),
      );
    }

    return Actions.invoke(
      context!,
      UpdateSelectionIntent(delegate.textEditingValue, newSelection, SelectionChangedCause.keyboard),
    );
  }

  @override
  bool get isActionEnabled => delegate.textEditingValue.selection.isValid;
}

class _ExtendSelectionOrCaretPositionAction extends ContextAction<ExtendSelectionToNextWordBoundaryOrCaretLocationIntent> {
  _ExtendSelectionOrCaretPositionAction(this.delegate, this.getTextBoundariesForIntent);

  final TextSelectionDelegate delegate;
  final TextBoundary Function(ExtendSelectionToNextWordBoundaryOrCaretLocationIntent intent) getTextBoundariesForIntent;

  @override
  Object? invoke(ExtendSelectionToNextWordBoundaryOrCaretLocationIntent intent, [BuildContext? context]) {
    final TextSelection selection = delegate.textEditingValue.selection;
    assert(selection.isValid);

    final TextBoundary textBoundary = getTextBoundariesForIntent(intent);
    final TextSelection textBoundarySelection = delegate.textEditingValue.selection;
    if (!textBoundarySelection.isValid) {
      return null;
    }

    final TextPosition extent = textBoundarySelection.extent;
    final TextPosition newExtent = intent.forward
      ? textBoundary.getTrailingTextBoundaryAt(extent)
      : textBoundary.getLeadingTextBoundaryAt(extent);

    final TextSelection newSelection = (newExtent.offset - textBoundarySelection.baseOffset) * (textBoundarySelection.extentOffset - textBoundarySelection.baseOffset) < 0
      ? textBoundarySelection.copyWith(
        extentOffset: textBoundarySelection.baseOffset,
        affinity: textBoundarySelection.extentOffset > textBoundarySelection.baseOffset ? TextAffinity.downstream : TextAffinity.upstream,
      )
      : textBoundarySelection.extendTo(newExtent);

    return Actions.invoke(
      context!,
      UpdateSelectionIntent(delegate.textEditingValue, newSelection, SelectionChangedCause.keyboard),
    );
  }

  @override
  bool get isActionEnabled => state.widget.selectionEnabled && delegate.textEditingValue.selection.isValid;
}

class _UpdateTextSelectionToAdjacentLineAction<T extends DirectionalCaretMovementIntent> extends ContextAction<T> {
  _UpdateTextSelectionToAdjacentLineAction(this.delegate);

  final TextSelectionDelegate delegate;

  VerticalCaretMovementRun? _verticalMovementRun;
  TextSelection? _runSelection;

  void stopCurrentVerticalRunIfSelectionChanges() {
    final TextSelection? runSelection = _runSelection;
    if (runSelection == null) {
      assert(_verticalMovementRun == null);
      return;
    }
    _runSelection = delegate.textEditingValue.selection;
    final TextSelection currentSelection = state.widget.controller.selection;
    final bool continueCurrentRun = currentSelection.isValid && currentSelection.isCollapsed
                                    && currentSelection.baseOffset == runSelection.baseOffset
                                    && currentSelection.extentOffset == runSelection.extentOffset;
    if (!continueCurrentRun) {
      _verticalMovementRun = null;
      _runSelection = null;
    }
  }

  @override
  void invoke(T intent, [BuildContext? context]) {
    assert(delegate.textEditingValue.selection.isValid);

    final bool collapseSelection = intent.collapseSelection || !state.widget.selectionEnabled;
    final TextEditingValue value = state._textEditingValueforTextLayoutMetrics;
    if (!value.selection.isValid) {
      return;
    }

    if (_verticalMovementRun?.isValid == false) {
      _verticalMovementRun = null;
      _runSelection = null;
    }

    final VerticalCaretMovementRun currentRun = _verticalMovementRun
      ?? state.renderEditable.startVerticalCaretMovement(state.renderEditable.selection!.extent);

    final bool shouldMove = intent.forward ? currentRun.moveNext() : currentRun.movePrevious();
    final TextPosition newExtent = shouldMove
      ? currentRun.current
      : (intent.forward ? TextPosition(offset: delegate.textEditingValue.text.length) : const TextPosition(offset: 0));
    final TextSelection newSelection = collapseSelection
      ? TextSelection.fromPosition(newExtent)
      : value.selection.extendTo(newExtent);

    Actions.invoke(
      context!,
      UpdateSelectionIntent(value, newSelection, SelectionChangedCause.keyboard),
    );
    if (delegate.textEditingValue.selection == newSelection) {
      _verticalMovementRun = currentRun;
      _runSelection = newSelection;
    }
  }

  @override
  bool get isActionEnabled => delegate.textEditingValue.selection.isValid;
}

class _SelectAllAction extends ContextAction<SelectAllTextIntent> {
  _SelectAllAction(this.delegate);

  final TextSelectionDelegate delegate;

  @override
  Object? invoke(SelectAllTextIntent intent, [BuildContext? context]) {
    return Actions.invoke(
      context!,
      UpdateSelectionIntent(
        delegate.textEditingValue,
        TextSelection(baseOffset: 0, extentOffset: delegate.textEditingValue.text.length),
        intent.cause,
      ),
    );
  }

  @override
  bool get isActionEnabled => state.widget.selectionEnabled;
}

class _CopySelectionAction extends ContextAction<CopySelectionTextIntent> {
  _CopySelectionAction(this.delegate);

  final TextSelectionDelegate delegate;

  @override
  void invoke(CopySelectionTextIntent intent, [BuildContext? context]) {
    if (intent.collapseSelection) {
      delegate.cutSelection(intent.cause);
    } else {
      delegate.copySelection(intent.cause);
    }
  }

  @override
  bool get isActionEnabled => delegate.textEditingValue.selection.isValid && !delegate.textEditingValue.selection.isCollapsed;
}
