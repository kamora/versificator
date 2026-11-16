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

The package is private and not on pub.dev. Add it as a git dependency pinned to a tag:

```yaml
dependencies:
  versificator:
    git:
      url: git@github.com:<owner>/versificator.git
      ref: v1.0.3
```

`flutter pub get` needs SSH access to the repository.

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
  // a recommended one also offers "Later":
  if (!update.required) {
    await versificator.postpone(update);
  }
}
```

- `check()` returns an `Update` (`version`, `required`) or null. It also returns null when the read fails, takes
  longer than `timeout` (30 seconds by default), or comes within `interval` (3 hours by default) of the last
  successful read, so it is cheap to call on every resume.
- `postpone(update)` stores a declined recommended version; `check()` won't ask for it again, only for a later one.
  A required update can't be postponed.

## Release

1. Run `flutter analyze` and `flutter test`.
2. Bump `version` in `pubspec.yaml` and commit.
3. Tag and push: `git tag v1.0.4 && git push origin main v1.0.4`.
4. In each app, change `ref` to the new tag, run `flutter pub get`, and commit `pubspec.yaml` with `pubspec.lock`.
