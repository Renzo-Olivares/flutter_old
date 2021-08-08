// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

class SupplementaryTextModel {
  SupplementaryTextModel({this.plainText = ''});

  String plainText;

  void insertCharacter(TextEditingController controller, String character) {
    plainText = controller.selection.textBefore(plainText) +
        character +
        controller.selection.textAfter(plainText);
    print(plainText);
  }

  /// Deletes backwards from the selection in [textSelectionDelegate].
  ///
  /// This method operates on the text/selection contained in
  /// [textSelectionDelegate], and does not depend on [selection].
  ///
  /// If the selection is collapsed, deletes a single character before the
  /// cursor.
  ///
  /// If the selection is not collapsed, deletes the selection.
  ///
  /// {@template flutter.rendering.RenderEditable.cause}
  /// The given [SelectionChangedCause] indicates the cause of this change and
  /// will be passed to [onSelectionChanged].
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///   * [deleteForward], which is same but in the opposite direction.
  // void delete(TextSelectionDelegate textSelectionDelegate) {
  void delete(ReplacementTextEditingController controller) {
    // `delete` does not depend on the text layout, and the boundary analysis is
    // done using the `previousCharacter` method instead of ICU, we can keep
    // deleting without having to layout the text. For this reason, we can
    // directly delete the character before the caret in the controller.
    //
    // TODO(LongCatIsLooong): remove this method from RenderEditable.
    // https://github.com/flutter/flutter/issues/80226.
    // final TextEditingValue controllerValue = textSelectionDelegate.textEditingValue;
    final TextSelection selection = controller.selection;

    // Current diff data.
    String textChanged;
    int start;
    int end;
    String diffType;

    print('deleting: '  + plainText);

    if (selection.start ==
        selection.end) {
      // Selection is collapsed, so we are deleting a single
      // character.
      textChanged = plainText.substring(
          selection.start - 1,
          selection.start);
      start = selection.start - 1;
      end = selection.start;
      diffType = 'DELETE';

      print('deleting: ' +
          plainText.substring(selection.start - 1,
              selection.start) +
          ' start: ' +
          selection.start.toString() +
          ' end: ' +
          selection.end.toString());
      plainText = plainText.substring(
          0, selection.start - 1) +
          plainText.substring(
              selection.start, plainText.length);
    } else {
      // We are deleting a selection.
      textChanged = selection.textInside(plainText);
      start = selection.start;
      end = selection.end;
      diffType = 'DELETE';

      print('deleting: ' +
          selection.textInside(plainText) +
          ' start: ' +
          selection.start.toString() +
          ' end: ' +
          selection.end.toString());
      plainText = selection.textBefore(plainText) +
          selection.textAfter(plainText);
    }
    controller.syncReplacementRanges(textChanged, start, end, diffType);
  }

  /// Deletes a word backwards from the current selection.
  ///
  /// If the [selection] is collapsed, deletes a word before the cursor.
  ///
  /// If the [selection] is not collapsed, deletes the selection.
  ///
  /// If [obscureText] is true, it treats the whole text content as
  /// a single word.
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// {@template flutter.rendering.RenderEditable.whiteSpace}
  /// By default, includeWhitespace is set to true, meaning that whitespace can
  /// be considered a word in itself.  If set to false, the selection will be
  /// extended past any whitespace and the first word following the whitespace.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///   * [deleteForwardByWord], which is same but in the opposite direction.
  void deleteByWord(TextSelectionDelegate textSelectionDelegate, [bool includeWhitespace = true]) {
  }

  /// Deletes a line backwards from the current selection.
  ///
  /// If the [selection] is collapsed, deletes a line before the cursor.
  ///
  /// If the [selection] is not collapsed, deletes the selection.
  ///
  /// If [obscureText] is true, it treats the whole text content as
  /// a single word.
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [deleteForwardByLine], which is same but in the opposite direction.
  void deleteByLine(TextSelectionDelegate textSelectionDelegate) {
    // assert(_selection != null);
    //
    // if (_readOnly || !_selection!.isValid) {
    //   return;
    // }
    //
    // if (!_selection!.isCollapsed) {
    //   return _deleteSelection(_selection!, cause);
    // }
    //
    // // When the text is obscured, the whole thing is treated as one big line.
    // if (obscureText) {
    //   return _deleteToStart(_selection!, cause);
    // }
    //
    // final String text = textSelectionDelegate.textEditingValue.text;
    // String textBefore = _selection!.textBefore(text);
    // if (textBefore.isEmpty) {
    //   return;
    // }
    //
    // // When there is a line break, line delete shouldn't do anything
    // final bool isPreviousCharacterBreakLine = textBefore.codeUnitAt(textBefore.length - 1) == 0x0A;
    // if (isPreviousCharacterBreakLine) {
    //   return;
    // }
    //
    // final TextSelection line = _getLineAtOffset(TextPosition(offset: textBefore.length - 1));
    // textBefore = textBefore.substring(0, line.start);
    //
    // final String textAfter = _selection!.textAfter(text);
    // final TextSelection newSelection = TextSelection.collapsed(offset: textBefore.length);
    // _setTextEditingValue(
    //   TextEditingValue(text: textBefore + textAfter, selection: newSelection),
    //   cause,
    // );
  }

  /// Deletes in the forward direction, from the current selection in
  /// [textSelectionDelegate].
  ///
  /// This method operates on the text/selection contained in
  /// [textSelectionDelegate], and does not depend on [selection].
  ///
  /// If the selection is collapsed, deletes a single character after the
  /// cursor.
  ///
  /// If the selection is not collapsed, deletes the selection.
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [delete], which is same but in the opposite direction.
  void deleteForward(TextSelectionDelegate textSelectionDelegate) {
    // // TODO(LongCatIsLooong): remove this method from RenderEditable.
    // // https://github.com/flutter/flutter/issues/80226.
    // final TextEditingValue controllerValue = textSelectionDelegate.textEditingValue;
    // final TextSelection selection = controllerValue.selection;
    //
    // if (!selection.isValid || _readOnly || _deleteNonEmptySelection(cause)) {
    //   return;
    // }
    //
    // assert(selection.isCollapsed);
    // final String textAfter = selection.textAfter(controllerValue.text);
    // if (textAfter.isEmpty) {
    //   return;
    // }
    //
    // final String textBefore = selection.textBefore(controllerValue.text);
    // final int characterBoundary = nextCharacter(0, textAfter);
    // final TextRange composing = controllerValue.composing;
    // final TextRange newComposingRange = !composing.isValid || composing.isCollapsed
    //     ? TextRange.empty
    //     : TextRange(
    //   start: composing.start - (composing.start - textBefore.length).clamp(0, characterBoundary),
    //   end: composing.end - (composing.end - textBefore.length).clamp(0, characterBoundary),
    // );
    // _setTextEditingValue(
    //   TextEditingValue(
    //     text: textBefore + textAfter.substring(characterBoundary),
    //     selection: selection,
    //     composing: newComposingRange,
    //   ),
    //   cause,
    // );
  }

  /// Deletes a word in the forward direction from the current selection.
  ///
  /// If the [selection] is collapsed, deletes a word after the cursor.
  ///
  /// If the [selection] is not collapsed, deletes the selection.
  ///
  /// If [obscureText] is true, it treats the whole text content as
  /// a single word.
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// {@macro flutter.rendering.RenderEditable.whiteSpace}
  ///
  /// See also:
  ///
  ///   * [deleteByWord], which is same but in the opposite direction.
  void deleteForwardByWord(TextSelectionDelegate textSelectionDelegate, [bool includeWhitespace = true]) {
    // assert(_selection != null);
    //
    // if (_readOnly || !_selection!.isValid) {
    //   return;
    // }
    //
    // if (!_selection!.isCollapsed) {
    //   return _deleteSelection(_selection!, cause);
    // }
    //
    // // When the text is obscured, the whole thing is treated as one big word.
    // if (obscureText) {
    //   return _deleteToEnd(_selection!, cause);
    // }
    //
    // final String text = textSelectionDelegate.textEditingValue.text;
    // String textAfter = _selection!.textAfter(text);
    //
    // if (textAfter.isEmpty) {
    //   return;
    // }
    //
    // final String textBefore = _selection!.textBefore(text);
    // final int characterBoundary = _getRightByWord(_textPainter, textBefore.length, includeWhitespace);
    // textAfter = textAfter.substring(characterBoundary - textBefore.length);
    //
    // _setTextEditingValue(
    //   TextEditingValue(text: textBefore + textAfter, selection: _selection!),
    //   cause,
    // );
  }

  /// Deletes a line in the forward direction from the current selection.
  ///
  /// If the [selection] is collapsed, deletes a line after the cursor.
  ///
  /// If the [selection] is not collapsed, deletes the selection.
  ///
  /// If [obscureText] is true, it treats the whole text content as
  /// a single word.
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [deleteByLine], which is same but in the opposite direction.
  void deleteForwardByLine(TextSelectionDelegate textSelectionDelegate) {
    // assert(_selection != null);
    //
    // if (_readOnly || !_selection!.isValid) {
    //   return;
    // }
    //
    // if (!_selection!.isCollapsed) {
    //   return _deleteSelection(_selection!, cause);
    // }
    //
    // // When the text is obscured, the whole thing is treated as one big line.
    // if (obscureText) {
    //   return _deleteToEnd(_selection!, cause);
    // }
    //
    // final String text = textSelectionDelegate.textEditingValue.text;
    // String textAfter = _selection!.textAfter(text);
    // if (textAfter.isEmpty) {
    //   return;
    // }
    //
    // // When there is a line break, it shouldn't do anything.
    // final bool isNextCharacterBreakLine = textAfter.codeUnitAt(0) == 0x0A;
    // if (isNextCharacterBreakLine) {
    //   return;
    // }
    //
    // final String textBefore = _selection!.textBefore(text);
    // final TextSelection line = _getLineAtOffset(TextPosition(offset: textBefore.length));
    // textAfter = textAfter.substring(line.end - textBefore.length, textAfter.length);
    //
    // _setTextEditingValue(
    //   TextEditingValue(text: textBefore + textAfter, selection: _selection!),
    //   cause,
    // );
  }

  /// Copy current [selection] to [Clipboard].
  void copySelection(TextSelectionDelegate textSelectionDelegate) {
    // final TextSelection selection = textSelectionDelegate.textEditingValue.selection;
    // final String text = textSelectionDelegate.textEditingValue.text;
    // assert(selection != null);
    // if (!selection.isCollapsed) {
    //   Clipboard.setData(ClipboardData(text: selection.textInside(text)));
    // }
  }

  /// Cut current [selection] to Clipboard.
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  void cutSelection(TextSelectionDelegate textSelectionDelegate) {
    // if (_readOnly) {
    //   return;
    // }
    // final TextSelection selection = textSelectionDelegate.textEditingValue.selection;
    // final String text = textSelectionDelegate.textEditingValue.text;
    // assert(selection != null);
    // if (!selection.isCollapsed) {
    //   Clipboard.setData(ClipboardData(text: selection.textInside(text)));
    //   _setTextEditingValue(
    //     TextEditingValue(
    //       text: selection.textBefore(text) + selection.textAfter(text),
    //       selection: TextSelection.collapsed(offset: math.min(selection.start, selection.end)),
    //     ),
    //     cause,
    //   );
    }
  }

  /// Paste text from [Clipboard].
  ///
  /// If there is currently a selection, it will be replaced.
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  Future<void> pasteText(TextSelectionDelegate textSelectionDelegate) async {
  //   if (_readOnly) {
  //     return;
  //   }
  //   final TextSelection selection = textSelectionDelegate.textEditingValue.selection;
  //   final String text = textSelectionDelegate.textEditingValue.text;
  //   assert(selection != null);
  //   // Snapshot the input before using `await`.
  //   // See https://github.com/flutter/flutter/issues/11427
  //   final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
  //   if (data != null && selection.isValid) {
  //     _setTextEditingValue(
  //       TextEditingValue(
  //         text: selection.textBefore(text) + data.text! + selection.textAfter(text),
  //         selection: TextSelection.collapsed(
  //           offset: math.min(selection.start, selection.end) + data.text!.length,
  //         ),
  //       ),
  //       cause,
  //     );
  //   }
  // }
}