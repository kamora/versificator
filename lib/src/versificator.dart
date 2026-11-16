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
    final current = installed.parts;
    if (data == null || current == null) {
      return null;
    }

    final required = data['required'];
    if (required is String && required.parts.after(current)) {
      return (version: required, required: true);
    }

    final recommended = data['recommended'];
    if (recommended is! String) {
      return null;
    }

    final version = recommended.parts;
    if (!version.after(current)) {
      return null;
    }

    if (!version.after(postponed.parts)) {
      return null;
    }

    return (version: recommended, required: false);
  }
}

extension on String? {
  /// The three numbers of this version, or null when it is missing or has another shape.
  List<int>? get parts {
    final numbers = this?.split('.').map(int.tryParse).toList();
    if (numbers == null) {
      return null;
    }

    if (numbers.length != 3) {
      return null;
    }

    if (numbers.contains(null)) {
      return null;
    }

    return numbers.cast<int>();
  }
}

extension on List<int>? {
  /// Whether this version is later than [b]. A malformed one never is; any version is later than a malformed [b].
  bool after(List<int>? b) {
    if (this == null) {
      return false;
    }

    if (b == null) {
      return true;
    }

    for (var i = 0; i < 3; i++) {
      if (this![i] != b[i]) {
        return this![i] > b[i];
      }
    }

    return false;
  }
}
