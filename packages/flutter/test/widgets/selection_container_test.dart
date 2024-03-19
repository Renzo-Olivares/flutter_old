// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  Future<void> pumpContainer(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultSelectionStyle(
          selectionColor: Colors.red,
          child: child,
        ),
      ),
    );
  }

  testWidgets('updates its registrar and delegate based on the number of selectables', (WidgetTester tester) async {
    final TestSelectionRegistrar registrar = TestSelectionRegistrar();
    final TestContainerDelegate delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: const Column(
          children: <Widget>[
            Text('column1', textDirection: TextDirection.ltr),
            Text('column2', textDirection: TextDirection.ltr),
            Text('column3', textDirection: TextDirection.ltr),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 1);
    expect(delegate.selectables.length, 3);
  });

  testWidgets('disabled container', (WidgetTester tester) async {
    final TestSelectionRegistrar registrar = TestSelectionRegistrar();
    final TestContainerDelegate delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: const SelectionContainer.disabled(
          child: Column(
            children: <Widget>[
              Text('column1', textDirection: TextDirection.ltr),
              Text('column2', textDirection: TextDirection.ltr),
              Text('column3', textDirection: TextDirection.ltr),
            ],
          ),
        ),
      ),
    );
    expect(registrar.selectables.length, 0);
    expect(delegate.selectables.length, 0);
  });

  testWidgets('Swapping out container delegate does not crash', (WidgetTester tester) async {
    final TestSelectionRegistrar registrar = TestSelectionRegistrar();
    final TestContainerDelegate delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);
    final TestContainerChildDelegate childDelegate = TestContainerChildDelegate();
    addTearDown(childDelegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: Builder(
          builder: (BuildContext context) {
            return SelectionContainer(
              // registrar: SelectionContainer.maybeOf(context),
              delegate: childDelegate,
              // child: Builder(
              //   builder: (BuildContext context) {
              //     debugPrint('insideee ${SelectionContainer.maybeOf(context)}');
              //     return RichText(
              //       selectionColor: Colors.green,
              //       selectionRegistrar: SelectionContainer.maybeOf(context),
              //       text: TextSpan(text: 'dummy'),
              //     );
              //   },
              // ),
              child: Text('dummy'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('child selectables ${childDelegate.selectables}');
    debugPrint('child has content ${childDelegate.value.hasContent}');
    debugPrint('child has content2 ${childDelegate.selectables.first.value.hasContent}');
    debugPrint('registar selectables ${registrar.selectables}');
    debugPrint('root delegate selectables ${delegate.selectables}');
    debugPrint('registar has content ${delegate.value.hasContent}');
    expect(childDelegate.selectables.length, 1);
    expect(registrar.selectables.length, 1);
    expect(delegate.value.hasContent, isTrue);

    // final TestContainerDelegate newDelegate = TestContainerDelegate();
    // addTearDown(newDelegate.dispose);

    // await pumpContainer(
    //   tester,
    //   SelectionContainer(
    //     registrar: registrar,
    //     delegate: delegate,
    //     child: Builder(
    //       builder: (BuildContext context) {
    //         return SelectionContainer(
    //           registrar: SelectionContainer.maybeOf(context),
    //           delegate: newDelegate,
    //           child: const Text('dummy'),
    //         );
    //       },
    //     )
    //   ),
    // );
    // await tester.pumpAndSettle();
    // expect(registrar.selectables.length, 1);
    // expect(delegate.value.hasContent, isTrue);
    // expect(tester.takeException(), isNull);
  });

  testWidgets('Can update within one frame', (WidgetTester tester) async {
    final TestSelectionRegistrar registrar = TestSelectionRegistrar();
    final TestContainerDelegate delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);
    final TestContainerDelegate childDelegate = TestContainerDelegate();
    addTearDown(childDelegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
          registrar: registrar,
          delegate: delegate,
          child: Builder(
            builder: (BuildContext context) {
              return SelectionContainer(
                registrar: SelectionContainer.maybeOf(context),
                delegate: childDelegate,
                child: const Text('dummy'),
              );
            },
          ),
      ),
    );
    await tester.pump();
    // Should finish update after flushing the micro tasks.
    await tester.idle();
    expect(registrar.selectables.length, 1);
    expect(delegate.value.hasContent, isTrue);
  });

  testWidgets('selection container registers itself if there is a selectable child', (WidgetTester tester) async {
    final TestSelectionRegistrar registrar = TestSelectionRegistrar();
    final TestContainerDelegate delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: const Column(
        ),
      ),
    );
    expect(registrar.selectables.length, 0);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: const Column(
          children: <Widget>[
            Text('column1', textDirection: TextDirection.ltr),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 1);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: const Column(
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 0);
  });

  testWidgets('selection container gets registrar from context if not provided', (WidgetTester tester) async {
    final TestSelectionRegistrar registrar = TestSelectionRegistrar();
    final TestContainerDelegate delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    await pumpContainer(
      tester,
      SelectionRegistrarScope(
        registrar: registrar,
        child: SelectionContainer(
          delegate: delegate,
          child: const Column(
            children: <Widget>[
              Text('column1', textDirection: TextDirection.ltr),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 1);
  });
}

class TestContainerDelegate extends MultiSelectableSelectionContainerDelegate {
  @override
  void add(Selectable selectable) {
    debugPrint('add in root delegate $selectable ${selectable.value.hasContent}');
    super.add(selectable);
  }

  @override
  void remove(Selectable selectable) {
    debugPrint('remove in root delegate $selectable');
    super.remove(selectable);
  }
  @override
  SelectionResult dispatchSelectionEventToChild(Selectable selectable, SelectionEvent event) {
    throw UnimplementedError();
  }

  @override
  void ensureChildUpdated(Selectable selectable) {
    throw UnimplementedError();
  }
}

class TestContainerChildDelegate extends MultiSelectableSelectionContainerDelegate {
  @override
  void add(Selectable selectable) {
    debugPrint('add in child delegate $selectable');
    super.add(selectable);
    notifyListeners();
  }

  @override
  void remove(Selectable selectable) {
    debugPrint('remove in child delegate $selectable');
    super.remove(selectable);
  }
  @override
  SelectionResult dispatchSelectionEventToChild(Selectable selectable, SelectionEvent event) {
    throw UnimplementedError();
  }

  @override
  void ensureChildUpdated(Selectable selectable) {
    throw UnimplementedError();
  }
}

class TestSelectionRegistrar extends SelectionRegistrar {
  final Set<Selectable> selectables = <Selectable>{};

  // @override
  // void add(Selectable selectable) => selectables.add(selectable);
  @override
  void add(Selectable selectable) {
    debugPrint('add in registar $selectable \n${StackTrace.current.toString()}\n');
    selectables.add(selectable);
  }

  @override
  void remove(Selectable selectable) {
    debugPrint('remove in registrar $selectable');
    selectables.remove(selectable);
  }

  // @override
  // void remove(Selectable selectable) => selectables.remove(selectable);
}
