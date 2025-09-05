#!/usr/bin/env dart
/// Automated test runner for EchoWright mobile app
/// This script runs comprehensive tests to verify app functionality

import 'dart:io';

void main(List<String> args) async {
  print('🧪 EchoWright App Test Runner');
  print('================================\n');

  final testTypes = args.isEmpty ? ['unit', 'widget', 'integration'] : args;

  for (final testType in testTypes) {
    await runTestSuite(testType);
  }

  print('\n🎉 All tests completed!');
  print('📊 Check the output above for detailed results');
}

Future<void> runTestSuite(String testType) async {
  print('🔍 Running $testType tests...\n');

  switch (testType) {
    case 'unit':
      await runUnitTests();
      break;
    case 'widget':
      await runWidgetTests();
      break;
    case 'integration':
      await runIntegrationTests();
      break;
    default:
      print('❌ Unknown test type: $testType');
      print('Available types: unit, widget, integration');
  }
}

Future<void> runUnitTests() async {
  print('🧮 Unit Tests - Testing core logic and services');
  await runFlutterTest('test/unit/services_test.dart');
}

Future<void> runWidgetTests() async {
  print('🎨 Widget Tests - Testing UI components and interactions');
  await runFlutterTest('test/widget/purchase_flow_test.dart');
  await runFlutterTest('test/widget/navigation_test.dart');
}

Future<void> runIntegrationTests() async {
  print('🔄 Integration Tests - Testing complete user flows');
  print('Note: Integration tests require a running device or emulator');
  await runFlutterTest('test/integration/app_flow_test.dart');
}

Future<void> runFlutterTest(String testFile) async {
  print('  Running: $testFile');
  
  final result = await Process.run(
    'flutter',
    ['test', testFile, '--verbose'],
    workingDirectory: '.',
  );

  if (result.exitCode == 0) {
    print('  ✅ Passed: $testFile');
    if (result.stdout.toString().isNotEmpty) {
      // Print key success messages
      final lines = result.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.contains('✅') || line.contains('All tests passed')) {
          print('    $line');
        }
      }
    }
  } else {
    print('  ❌ Failed: $testFile');
    print('    Error: ${result.stderr}');
    if (result.stdout.toString().isNotEmpty) {
      print('    Output: ${result.stdout}');
    }
  }
  print('');
}