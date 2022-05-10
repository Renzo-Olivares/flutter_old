// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/commands/update_packages.dart';

import '../src/common.dart';

// An example pubspec.yaml from flutter, not necessary for it to be up to date.
const String kFlutterPubspecYaml = r'''
name: flutter
description: A framework for writing Flutter applications
homepage: http://flutter.dev

environment:
  sdk: '>=2.2.2 <3.0.0'

dependencies:
  # To update these, use "flutter update-packages --force-upgrade".
  collection: 1.14.11
  meta: 1.1.8
  typed_data: 1.1.6
  vector_math: 2.0.8

  sky_engine:
    sdk: flutter

  gallery:
    git:
      url: https://github.com/flutter/gallery.git
      ref: d00362e6bdd0f9b30bba337c358b9e4a6e4ca950

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_goldens:
    sdk: flutter

  archive: 2.0.11 # THIS LINE IS AUTOGENERATED - TO UPDATE USE "flutter update-packages --force-upgrade"

# PUBSPEC CHECKSUM: 1437
''';

const String kExtraPubspecYaml = r'''
name: nodeps
description: A dummy pubspec with no dependencies
homepage: http://flutter.dev

environment:
  sdk: ">=2.2.2 <3.0.0"
''';

const String kInvalidGitPubspec = '''
name: flutter
description: A framework for writing Flutter applications
homepage: http://flutter.dev

environment:
  sdk: ">=2.2.2 <3.0.0"

dependencies:
  # To update these, use "flutter update-packages --force-upgrade".
  collection: 1.14.11
  meta: 1.1.8
  typed_data: 1.1.6
  vector_math: 2.0.8

  sky_engine:
    sdk: flutter

  gallery:
    git:
''';

void main() {
  FileSystem fileSystem;
  Directory flutterSdk;
  Directory flutter;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    // Setup simplified Flutter SDK.
    flutterSdk = fileSystem.directory('flutter')..createSync();
    // Create version file
    flutterSdk.childFile('version').writeAsStringSync('1.2.3');
    // Create a pubspec file
    flutter = flutterSdk.childDirectory('packages').childDirectory('flutter')
      ..createSync(recursive: true);
    flutter.childFile('pubspec.yaml').writeAsStringSync(kFlutterPubspecYaml);
  });

  testWithoutContext(
      'createTemporaryFlutterSdk creates an unpinned flutter SDK', () {
    // A stray extra package should not cause a crash.
    final Directory extra = flutterSdk
        .childDirectory('packages')
        .childDirectory('extra')
      ..createSync(recursive: true);
    extra.childFile('pubspec.yaml').writeAsStringSync(kExtraPubspecYaml);

    // Create already parsed pubspecs.
    final PubspecYaml flutterPubspec = PubspecYaml(flutter);

    final PubspecDependency gitDependency = flutterPubspec.dependencies
        .firstWhere((PubspecDependency dep) => dep.kind == DependencyKind.git);
    expect(
      gitDependency.lockLine,
      '''
    git:
      url: https://github.com/flutter/gallery.git
      ref: d00362e6bdd0f9b30bba337c358b9e4a6e4ca950
''',
    );
    final BufferLogger bufferLogger = BufferLogger.test();
    final Directory result = createTemporaryFlutterSdk(
      bufferLogger,
      fileSystem,
      flutterSdk,
      <PubspecYaml>[flutterPubspec],
    );

    expect(result, exists);

    // We get a warning about the unexpected package.
    expect(
      bufferLogger.warningText,
      contains("Unexpected package 'extra' found in packages directory"),
    );

    // The version file exists.
    expect(result.childFile('version'), exists);
    expect(result.childFile('version').readAsStringSync(), '1.2.3');

    // The sky_engine package exists
    expect(fileSystem.directory('${result.path}/bin/cache/pkg/sky_engine'), exists);

    // The flutter pubspec exists
    final File pubspecFile = fileSystem.file('${result.path}/packages/flutter/pubspec.yaml');
    expect(pubspecFile, exists);

    // The flutter pubspec contains `any` dependencies.
    final PubspecYaml outputPubspec = PubspecYaml(pubspecFile.parent);
    expect(outputPubspec.name, 'flutter');
    expect(outputPubspec.dependencies.first.name, 'collection');
    expect(outputPubspec.dependencies.first.version, 'any');
  });

  testWithoutContext('Throws a StateError on a malformed git: reference', () {
    // Create an invalid pubspec file.
    flutter.childFile('pubspec.yaml').writeAsStringSync(kInvalidGitPubspec);

    expect(
      () => PubspecYaml(flutter),
      throwsStateError,
    );
  });

  testWithoutContext('PubspecYaml Loads dependencies', () async {
    final PubspecYaml pubspecYaml = PubspecYaml(flutter);
    expect(
        pubspecYaml.allDependencies
            .map<String>((PubspecDependency dependency) => '${dependency.name}: ${dependency.version}')
            .toSet(),
        equals(<String>{
          'collection: 1.14.11',
          'meta: 1.1.8',
          'typed_data: 1.1.6',
          'vector_math: 2.0.8',
          'sky_engine: ',
          'gallery: ',
          'flutter_test: ',
          'flutter_goldens: ',
          'archive: 2.0.11',
        }));
    expect(
        pubspecYaml.allExplicitDependencies
            .map<String>((PubspecDependency dependency) => '${dependency.name}: ${dependency.version}')
            .toSet(),
        equals(<String>{
          'collection: 1.14.11',
          'meta: 1.1.8',
          'typed_data: 1.1.6',
          'vector_math: 2.0.8',
          'sky_engine: ',
          'gallery: ',
          'flutter_test: ',
          'flutter_goldens: ',
        }));
    expect(
        pubspecYaml.dependencies
            .map<String>((PubspecDependency dependency) => '${dependency.name}: ${dependency.version}')
            .toSet(),
        equals(<String>{
          'collection: 1.14.11',
          'meta: 1.1.8',
          'typed_data: 1.1.6',
          'vector_math: 2.0.8',
          'sky_engine: ',
          'gallery: ',
        }));
  });
}
