// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first frame callback sets the default UserTag', () {
      final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

      expect(developer.getCurrentTag().label, equals('Default'));
      developer.UserTag('test tag').makeCurrent();
      expect(developer.getCurrentTag().label, equals('test tag'));

      binding.drawFrame();
      // Simulates the engine again.
      binding.window.onReportTimings!(<FrameTiming>[]);

      expect(developer.getCurrentTag().label, equals('Default'));
  });
}
