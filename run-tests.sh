#!/bin/bash

paths=$(find . -wholename "./integration_test/features/05*/$1*.feature" | sort | sed -z "s/\\n/','/g;s/,'$//;s/^/'/")
sed "s|featurePaths: REPLACED_BY_SCRIPT|featurePaths: <String>[$paths]|" integration_test/gherkin_suite_test.editable.dart > integration_test/gherkin_suite_test.dart
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
pkill tor
LD_LIBRARY_PATH=/home/erinn/Android/Goprojects/libcwtch-go/ CWTCH_HOME=./integration_test/env/temp/ flutter drive --dart-define TEST_MODE=true --driver=test_driver/integration_test_driver.dart --target=integration_test/gherkin_suite_test.dart
node index2.js
xdg-open integration_test/gherkin/reports/cucumber_report.html
