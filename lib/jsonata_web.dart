// jsonata_web.dart
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class Jsonata {
  String jql = "";
  String data = "";

  Jsonata([String? jql]) {
    if (jql != null) {
      this.jql = jql.trim();
    }
  }

  void set({dynamic data, dynamic jql}) {
    if (data != null) {
      this.data = data;
    }
    if (jql != null) {
      this.jql = jql;
    }
  }

  Future<Map> query([String? jql]) async {
    if (jql != null) {
      this.jql = jql.trim();
    }
    var result = await evaluate(data);
    return result;
  }

  Future<void> initialize() async {
    // No need to initialize anything for web
  }

  Future<Map> evaluate(String data) async {
    this.data = data.trim();

    final completer = Completer<Map>();

    js.context.callMethod('jsonataQuery', [
      jql,
      this.data,
      (result) {
        completer.complete({'value': result, 'error': null});
      },
      (error) {
        completer.complete({'value': null, 'error': error});
      }
    ]);

    return completer.future;
  }

  void dispose() {
    // No need to dispose anything for web
  }
}