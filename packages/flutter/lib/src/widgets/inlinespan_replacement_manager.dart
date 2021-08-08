// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'editable_text.dart';
import 'framework.dart';
import 'dart:math' as math;

class InlineSpanReplacementManager {
  /// The [TextEditingInlineSpanReplacement]s that are evaluated on the editing value.
  ///
  /// Each replacement is evaluated in order from first to last. If multiple replacement
  /// [TextRange]s match against the same range of text,
  /// TODO: What happens when replacements match against same range of text?
  ///
  /// TODO: Give an example of replacements matching against the same range of text.
  ///
  ///
  ///
  InlineSpanReplacementManager({this.plainText = ''});

  String plainText;

  void insertCharacter(TextEditingController controller, String character) {
    // plainText = controller.selection.textBefore(plainText) +
    //     character +
    //     controller.selection.textAfter(plainText);
    // print(plainText);
    replace(controller.selection.start, controller.selection.end, character, 0, character.length);
  }

  void replace(int start, int end, String tb, int tbstart, int tbend) {
    print(plainText);
    
  }

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
    // controller.syncReplacementRanges(textChanged, start, end, diffType);
  }
  ///
  ///
  ///


  List<TextEditingInlineSpanReplacement> replacements = [];
  List<int> replacementStartingPositions = [];
  List<int> replacementEndingPositions = [];
  List<int> replacementMaxes = [];
  List<int> replacementOrder = [];
  Map<TextEditingInlineSpanReplacement, int> indexOfReplacements = {};
  int replacementInsertCount = 0;
  int replacementCount = 0;
  int lowWaterMark = 0; // indices below this have not been touched. maybe make this nullable
  int gapStart = 0; //init to length of string
  int gapLength = 0; //end - start

  // Primitives for treating span list as binary tree

  // The spans (along with start and end offsets and flags) are stored in linear arrays sorted
  // by start offset. For fast searching, there is a binary search structure imposed over these
  // arrays. This structure is inorder traversal of a perfect binary tree, a slightly unusual
  // but advantageous approach.

  // The value-containing nodes are indexed 0 <= i < n (where n = mSpanCount), thus preserving
  // logic that accesses the values as a contiguous array. Other balanced binary tree approaches
  // (such as a complete binary tree) would require some shuffling of node indices.

  // Basic properties of this structure: For a perfect binary tree of height m:
  // The tree has 2^(m+1) - 1 total nodes.
  // The root of the tree has index 2^m - 1.
  // All leaf nodes have even index, all interior nodes odd.
  // The height of a node of index i is the number of trailing ones in i's binary representation.
  // The left child of a node i of height h is i - 2^(h - 1).
  // The right child of a node i of height h is i + 2^(h - 1).

  // Note that for arbitrary n, interior nodes of this tree may be >= n. Thus, the general
  // structure of a recursive traversal of node i is:
  // * traverse left child if i is an interior node
  // * process i if i < n
  // * traverse right child if i is an interior node and i < n

  int _treeRoot() {
    return _highestOneBit(replacementCount) - 1;
  }

  // TODO: https://pub.dev/documentation/scidart/latest/numdart/highestOneBit.html
  int _highestOneBit(int n) {
    n |= (n >> 1);
    n |= (n >> 2);
    n |= (n >> 4);
    n |= (n >> 8);
    n |= (n >> 16);
    return n - (n >> 1);
  }

  // (i+1) & ~i is equal to 2^(the number of trailing ones in i)
  static int _leftChild(int i) {
    return i - (((i + 1) & ~i) >> 1);
  }

  static int _rightChild(int i) {
    return i + (((i + 1) & ~i) >> 1);
  }

  // The span arrays are also augmented by an mSpanMax[] array that represents an interval tree
  // over the binary tree structure described above. For each node, the mSpanMax[] array contains
  // the maximum value of mSpanEnds of that node and its descendants. Thus, traversals can
  // easily reject subtrees that contain no spans overlapping the area of interest.

  // Note that mSpanMax[] also has a valid valuefor interior nodes of index >= n, but which have
  // descendants of index < n. In these cases, it simply represents the maximum span end of its
  // descendants. This is a consequence of the perfect binary tree structure.
  int _calcMax(int i) {
    int max = 0;
    if ((i & 1) != 0) {
      // internal tree node
      max = _calcMax(_leftChild(i));
    }
    if (i < replacementCount) {
      max = math.max(max, replacementEndingPositions[i]);
      if ((i & 1) != 0) {
        max = math.max(max, _calcMax(_rightChild(i)));
      }
    }
    replacementMaxes[i] = max;
    return max;
  }

  // restores binary interval tree invariants after any mutation of span structure
  void _restoreInvariants() {
    if (replacementCount == 0) return;

    // invariant 1: span starts are nondecreasing

    // This is a simple insertion sort because we expect it to be mostly sorted.
    for (int i = 1; i < replacementCount; i++) {
      if (replacementStartingPositions[i] < replacementEndingPositions[i - 1]) {
        TextEditingInlineSpanReplacement replacement = replacements[i];
        int start = replacementStartingPositions[i];
        int end = replacementEndingPositions[i];
        // int flags = replacementFlags[i];
        int insertionOrder = replacementOrder[i];
        int j = i;
        do {
          replacements[j] = replacements[j - 1];
          replacementStartingPositions[j] = replacementStartingPositions[j - 1];
          replacementEndingPositions[j] = replacementEndingPositions[j - 1];
          // replacementFlags[j] = replacementFlags[j - 1];
          replacementOrder[j] = replacementOrder[j - 1];
          j--;
        } while (j > 0 && start < replacementStartingPositions[j - 1]);
        replacements[j] = replacement;
        replacementStartingPositions[j] = start;
        replacementEndingPositions[j] = end;
        // replacementFlags[j] = flags;
        replacementOrder[j] = insertionOrder;
        _invalidateIndex(j);
      }
    }

    // invariant 2: max is max span end for each node and its descendants
    _calcMax(_treeRoot());

    // invariant 3: mIndexOfSpan maps spans back to indices
    if (indexOfReplacements == null) {
      indexOfReplacements = <TextEditingInlineSpanReplacement, int>{};
    }
    for (int i = lowWaterMark; i < replacementCount; i++) {
      int? existing = indexOfReplacements[replacements[i]];
      if (existing == null || existing != i) {
        indexOfReplacements[replacements[i]] = i;
      }
    }
    final int minInt = (double.infinity is int) ? -double.infinity as int : (-1 << 63);
    final int maxInt = (double.infinity is int) ? double.infinity as int : ~minInt;

    lowWaterMark = maxInt;
  }

  // Call this on any update to mSpans[], so that mIndexOfSpan can be updated
  void _invalidateIndex(int i) {
    lowWaterMark = math.min(i, lowWaterMark);
  }

  void setSpan(TextEditingInlineSpanReplacement replacement) {
    int start = replacement.range.start;
    int end = replacement.range.end;
    int nstart = replacement.range.start;
    int nend = replacement.range.end;

    if (start > gapStart) {
      start += gapLength;
    } else if (start == gapStart) {
      // if (flagsStart == POINT || (flagsStart == PARAGRAPH && start == length()))
        start += gapLength;
    }

    if (end > gapStart) {
      end += gapLength;
    } else if (end == gapStart) {
      // if (flagsEnd == POINT || (flagsEnd == PARAGRAPH && end == length()))
        end += gapLength;
    }

    if (indexOfReplacements != null) {
      int? index = indexOfReplacements[replacement];
      if (index != null) {
        int i = index;
        int ostart = replacementStartingPositions[i];
        int oend = replacementEndingPositions[i];

        if (ostart > gapStart)
          ostart -= gapLength;
        if (oend > gapStart)
          oend -= gapLength;

        replacementStartingPositions[i] = start;
        replacementEndingPositions[i] = end;
        // replacementFlags[i] = flags;

        // if (send) {
        if (true) {
          _restoreInvariants();
          // sendSpanChanged(what, ostart, oend, nstart, nend);
        }

        return;
      }
    }

    replacements.add(replacement);
    replacementStartingPositions.add(start);
    replacementEndingPositions.add(end);
    // replacementFlags.add(flags);
    replacementOrder.add(replacementInsertCount);
    _invalidateIndex(replacementCount);
    replacementCount++;
    replacementInsertCount++;
    // Make sure there is enough room for empty interior nodes.
    // This magic formula computes the size of the smallest perfect binary
    // tree no smaller than mSpanCount.
    int sizeOfMax = 2 * _treeRoot() + 1;
    if (replacementMaxes.length < sizeOfMax) {
      replacementMaxes = new List<int>.filled(sizeOfMax, -1, growable: true);
      // replacementMaxes = [];
    }

    print(replacements);
    print(replacementStartingPositions);
    print(replacementEndingPositions);
    print(replacementOrder);
    print(replacementCount);
    print(replacementInsertCount);

    // if (send) {
    if (true) {
      _restoreInvariants();
      // sendSpanAdded(what, nstart, nend);
    }
  }
}

