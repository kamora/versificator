# versificator

Checks a Flutter app's installed version against a Firestore document and tells the app whether an update is
required or recommended. It only answers the question; the app shows its own dialogs.

## Firestore

One document per app, such as `versions/<app>`, with two string fields:

| Field | Meaning |
|---|---|
| `required` | Versions older than this can't be used; the update is forced. |
| `recommended` | Versions older than this are asked to update, and may decline. |

Versions have exactly three numbers (`5.1.0`). A missing or malformed field asks for nothing. One document serves
both iOS and Android, so keep the platforms' versions in sync.

The package signs in anonymously when nobody is signed in, so the security rules only need to allow reads by
authenticated users.

## Install

```
flutter pub add versificator
```

The app needs Firebase set up with Firestore and anonymous authentication enabled.

## Use

Initialize Firebase first, then create one `Versificator` and keep it for the app's lifetime:

```dart
final versificator = Versificator('versions/my-app');

Future<void> checkForUpdate() async {
  final update = await versificator.check();
  if (update == null) {
    return;
  }

  // Show a dialog for update.version. A required update offers only the store;
  // a recommended one also offers "Later", which calls later(update).
}

Future<void> later(Update update) => versificator.postpone(update);
```

- `check()` returns an `Update` (`version`, `required`) or null. It also returns null when the read fails, takes
  longer than `timeout` (30 seconds by default), or comes within `interval` (3 hours by default) of the last
  successful read, so it is cheap to call on every resume.
- `postpone(update)` stores a declined recommended version; `check()` won't ask for it again, only for a later one.
  A required update can't be postponed.

## Release

1. Run `flutter analyze` and `flutter test`.
2. Bump `version` in `pubspec.yaml`, add its entry to `CHANGELOG.md`, and commit.
3. Run `dart pub publish --dry-run`; it must report no issues.
4. Tag and push: `git tag v1.0.5 && git push origin main v1.0.5`.
5. Publish: `dart pub publish`.
