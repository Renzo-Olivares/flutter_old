// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextEditingDeltaInsertion', () {
    test('Verify creation of insertion delta when inserting at a collapsed selection.', () {
      const String jsonInsertionDelta = '{'
          '"oldText": "",'
          ' "deltaText": "let there be text",'
          ' "deltaStart": 0,'
          ' "deltaEnd": 0,'
          ' "selectionBase": 17,'
          ' "selectionExtent": 17,'
          ' "selectionAffinity" : "TextAffinity.downstream" ,'
          ' "selectionIsDirectional": false,'
          ' "composingBase": -1,'
          ' "composingExtent": -1}';
      final TextEditingDelta delta = TextEditingDelta.fromJSON(jsonDecode(jsonInsertionDelta) as Map<String, dynamic>);
      const TextRange expectedComposing = TextRange.empty;
      const TextRange expectedDeltaRange = TextRange.collapsed(0);
      const TextSelection expectedSelection = TextSelection.collapsed(offset: 17);

      expect(delta.oldText, '');
      expect(delta.deltaText, 'let there be text');
      expect(delta.deltaType, TextEditingDeltaType.insertion);
      expect(delta.deltaRange, expectedDeltaRange);
      expect(delta.selection, expectedSelection);
      expect(delta.composing, expectedComposing);
    });

    test('Verify creation of insertion delta when inserting at end of composing region.', () {
      const String jsonInsertionDelta = '{'
          '"oldText": "hello worl",'
          ' "deltaText": "world",'
          ' "deltaStart": 6,'
          ' "deltaEnd": 10,'
          ' "selectionBase": 11,'
          ' "selectionExtent": 11,'
          ' "selectionAffinity" : "TextAffinity.downstream",'
          ' "selectionIsDirectional": false,'
          ' "composingBase": 6,'
          ' "composingExtent": 11}';

      final TextEditingDelta delta = TextEditingDelta.fromJSON(jsonDecode(jsonInsertionDelta) as Map<String, dynamic>);
      const TextRange expectedComposing = TextRange(start: 6, end: 11);
      const TextRange expectedDeltaRange = TextRange.collapsed(10);
      const TextSelection expectedSelection = TextSelection.collapsed(offset: 11);

      expect(delta.oldText, 'hello worl');
      expect(delta.deltaText, 'd');
      expect(delta.deltaType, TextEditingDeltaType.insertion);
      expect(delta.deltaRange, expectedDeltaRange);
      expect(delta.selection, expectedSelection);
      expect(delta.composing, expectedComposing);
    });
  });

  group('TextEditingDeltaDeletion', () {
    test('Verify creation of deletion delta when deleting.', () {
      const String jsonDeletionDelta = '{'
          '"oldText": "let there be text.",'
          ' "deltaText": "",'
          ' "deltaStart": 1,'
          ' "deltaEnd": 2,'
          ' "selectionBase": 1,'
          ' "selectionExtent": 1,'
          ' "selectionAffinity" : "TextAffinity.downstream" ,'
          ' "selectionIsDirectional": false,'
          ' "composingBase": -1,'
          ' "composingExtent": -1}';

      final TextEditingDelta delta = TextEditingDelta.fromJSON(jsonDecode(jsonDeletionDelta) as Map<String, dynamic>);
      const TextRange expectedComposing = TextRange.empty;
      const TextRange expectedDeltaRange = TextRange(start: 1, end: 2);
      const TextSelection expectedSelection = TextSelection.collapsed(offset: 1);

      expect(delta.oldText, 'let there be text.');
      expect(delta.deltaText, '');
      expect(delta.deltaType, TextEditingDeltaType.deletion);
      expect(delta.deltaRange, expectedDeltaRange);
      expect(delta.selection, expectedSelection);
      expect(delta.composing, expectedComposing);
    });

    test('Verify creation of deletion delta when deleting at end of composing region.', () {
      const String jsonDeletionDelta = '{'
          '"oldText": "hello world",'
          ' "deltaText": "worl",'
          ' "deltaStart": 6,'
          ' "deltaEnd": 11,'
          ' "selectionBase": 10,'
          ' "selectionExtent": 10,'
          ' "selectionAffinity" : "TextAffinity.downstream",'
          ' "selectionIsDirectional": false,'
          ' "composingBase": 6,'
          ' "composingExtent": 10}';

      final TextEditingDelta delta = TextEditingDelta.fromJSON(jsonDecode(jsonDeletionDelta) as Map<String, dynamic>);
      const TextRange expectedComposing = TextRange(start: 6, end: 10);
      const TextRange expectedDeltaRange = TextRange(start: 10, end: 11);
      const TextSelection expectedSelection = TextSelection.collapsed(offset: 10);

      expect(delta.oldText, 'hello world');
      expect(delta.deltaText, '');
      expect(delta.deltaType, TextEditingDeltaType.deletion);
      expect(delta.deltaRange, expectedDeltaRange);
      expect(delta.selection, expectedSelection);
      expect(delta.composing, expectedComposing);
    });
  });

  group('TextEditingDeltaReplacement', () {
    test('Verify creation of replacement delta when replacing with longer.', () {
      const String jsonReplacementDelta = '{'
          '"oldText": "hello worfi",'
          ' "deltaText": "working",'
          ' "deltaStart": 6,'
          ' "deltaEnd": 11,'
          ' "selectionBase": 13,'
          ' "selectionExtent": 13,'
          ' "selectionAffinity" : "TextAffinity.downstream",'
          ' "selectionIsDirectional": false,'
          ' "composingBase": 6,'
          ' "composingExtent": 13}';

      final TextEditingDelta delta = TextEditingDelta.fromJSON(jsonDecode(jsonReplacementDelta) as Map<String, dynamic>);
      const TextRange expectedComposing = TextRange(start: 6, end: 13);
      const TextRange expectedDeltaRange = TextRange(start: 6, end: 11);
      const TextSelection expectedSelection = TextSelection.collapsed(offset: 13);

      expect(delta.oldText, 'hello worfi');
      expect(delta.deltaText, 'working');
      expect(delta.deltaType, TextEditingDeltaType.replacement);
      expect(delta.deltaRange, expectedDeltaRange);
      expect(delta.selection, expectedSelection);
      expect(delta.composing, expectedComposing);
    });

    test('Verify creation of replacement delta when replacing with shorter.', () {
      const String jsonReplacementDelta = '{'
          '"oldText": "hello world",'
          ' "deltaText": "h",'
          ' "deltaStart": 6,'
          ' "deltaEnd": 11,'
          ' "selectionBase": 7,'
          ' "selectionExtent": 7,'
          ' "selectionAffinity" : "TextAffinity.downstream",'
          ' "selectionIsDirectional": false,'
          ' "composingBase": 6,'
          ' "composingExtent": 7}';

      final TextEditingDelta delta = TextEditingDelta.fromJSON(jsonDecode(jsonReplacementDelta) as Map<String, dynamic>);
      const TextRange expectedComposing = TextRange(start: 6, end: 7);
      const TextRange expectedDeltaRange = TextRange(start: 6, end: 11);
      const TextSelection expectedSelection = TextSelection.collapsed(offset: 7);

      expect(delta.oldText, 'hello world');
      expect(delta.deltaText, 'h');
      expect(delta.deltaType, TextEditingDeltaType.replacement);
      expect(delta.deltaRange, expectedDeltaRange);
      expect(delta.selection, expectedSelection);
      expect(delta.composing, expectedComposing);
    });

    test('Verify creation of replacement delta when replacing with same.', () {
      const String jsonReplacementDelta = '{'
          '"oldText": "hello world",'
          ' "deltaText": "words",'
          ' "deltaStart": 6,'
          ' "deltaEnd": 11,'
          ' "selectionBase": 11,'
          ' "selectionExtent": 11,'
          ' "selectionAffinity" : "TextAffinity.downstream",'
          ' "selectionIsDirectional": false,'
          ' "composingBase": 6,'
          ' "composingExtent": 11}';

      final TextEditingDelta delta = TextEditingDelta.fromJSON(jsonDecode(jsonReplacementDelta) as Map<String, dynamic>);
      const TextRange expectedComposing = TextRange(start: 6, end: 11);
      const TextRange expectedDeltaRange = TextRange(start: 6, end: 11);
      const TextSelection expectedSelection = TextSelection.collapsed(offset: 11);

      expect(delta.oldText, 'hello world');
      expect(delta.deltaText, 'words');
      expect(delta.deltaType, TextEditingDeltaType.replacement);
      expect(delta.deltaRange, expectedDeltaRange);
      expect(delta.selection, expectedSelection);
      expect(delta.composing, expectedComposing);
    });
  });

  group('TextEditingDeltaNonTextUpdate', () {
    test('Verify non text update delta created.', () {
      const String jsonNonTextUpdateDelta = '{'
          '"oldText": "hello world",'
          ' "deltaText": "",'
          ' "deltaStart": -1,'
          ' "deltaEnd": -1,'
          ' "selectionBase": 10,'
          ' "selectionExtent": 10,'
          ' "selectionAffinity" : "TextAffinity.downstream",'
          ' "selectionIsDirectional": false,'
          ' "composingBase": 6,'
          ' "composingExtent": 11}';

      final TextEditingDelta delta = TextEditingDelta.fromJSON(jsonDecode(jsonNonTextUpdateDelta) as Map<String, dynamic>);
      const TextRange expectedComposing = TextRange(start: 6, end: 11);
      const TextRange expectedDeltaRange = TextRange.empty;
      const TextSelection expectedSelection = TextSelection.collapsed(offset: 10);

      expect(delta.oldText, 'hello world');
      expect(delta.deltaText, '');
      expect(delta.deltaType, TextEditingDeltaType.nonTextUpdate);
      expect(delta.deltaRange, expectedDeltaRange);
      expect(delta.selection, expectedSelection);
      expect(delta.composing, expectedComposing);
    });
  });
}
