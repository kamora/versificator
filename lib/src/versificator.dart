import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An update to ask for: the version to update to, and whether the app can't be used without it.
typedef Update = ({String version, bool required});

/// Reads an app's version requirements from a Firestore document with the string fields `required` and
/// `recommended`, versions of three numbers such as `5.1.0`. It signs in anonymously when nobody is signed in; the app
/// initializes Firebase first.
class Versificator {
  Versificator(this.path, {this.interval = const Duration(hours: 3), this.timeout = const Duration(seconds: 30)});

  /// The document, such as `versions/price-advice`.
  final String path;

  /// How long after a successful read [check] answers null without reading again.
  final Duration interval;

  /// How long a read may take.
  final Duration timeout;

  static const _key = 'versificator.postponed';

  /// When the document was last read.
  DateTime? _checked;

  /// The update the installed version needs, or null: when there is none, when the read fails or takes longer than
  /// [timeout], or within [interval] of the last read.
  Future<Update?> check() async {
    final now = DateTime.now();
    if (_checked != null && now.difference(_checked!) < interval) {
      return null;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        log('Anonymous sign-in failed: $e', name: 'versificator');
      }
    }

    try {
      final data = (await FirebaseFirestore.instance.doc(path).get().timeout(timeout)).data();
      _checked = now;
      return evaluate(
        data,
        (await PackageInfo.fromPlatform()).version,
        (await SharedPreferences.getInstance()).getString(_key),
      );
    } catch (e) {
      log('Version check failed: $e', name: 'versificator');
      return null;
    }
  }

  /// Puts off a recommended update: [check] won't ask for it again, only for a later one. A required update can't be
  /// put off.
  Future<void> postpone(Update update) async {
    if (!update.required) {
      await (await SharedPreferences.getInstance()).setString(_key, update.version);
    }
  }

  /// The update [data] asks of the [installed] version: required when it is older than `required`, recommended when
  /// it is older than `recommended` and that is later than the [postponed] version. A missing or malformed field asks
  /// for nothing.
  @visibleForTesting
  static Update? evaluate(Map<String, dynamic>? data, String installed, String? postponed) {
    final current = _parse(installed);
    if (data == null || current == null) {
      return null;
    }

    final required = data['required'];
    if (required is String && _later(_parse(required), current)) {
      return (version: required, required: true);
    }

    final recommended = data['recommended'];
    if (recommended is! String) {
      return null;
    }

    final version = _parse(recommended);
    return _later(version, current) && _later(version, _parse(postponed))
        ? (version: recommended, required: false)
        : null;
  }

  /// The three numbers of [version], or null when it is missing or has another shape.
  static List<int>? _parse(String? version) {
    final parts = version?.split('.').map(int.tryParse).toList();
    return parts != null && parts.length == 3 && !parts.contains(null) ? parts.cast<int>() : null;
  }

  /// Whether [a] is later than [b]. A malformed [a] never is; any version is later than a malformed [b].
  static bool _later(List<int>? a, List<int>? b) {
    if (a == null) {
      return false;
    }

    if (b == null) {
      return true;
    }

    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) {
        return a[i] > b[i];
      }
    }

    return false;
  }
}
