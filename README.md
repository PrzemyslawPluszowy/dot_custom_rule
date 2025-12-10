# dot_shorthand_custom_lint — krótkie README / short README

PL
--
Opis
- Pakiet z regułami `custom_lint` dotyczący skrótów z kropką (dot-shorthand).
- Plik główny z pluginem to `lib/dot_linter.dart`. 

Instalacja (z GitHub)
1. W `pubspec.yaml` projektu-klienta dodaj:

```yaml
dependencies:
  dot_shorthand_custom_lint:
    git:
      url: https://github.com/PrzemyslawPluszowy/dot_custom_rule.git
      ref: main
```

2. Uruchom:
```bash
dart pub get
```
3. Zrestartuj IDE/analizator (jeśli potrzebne).

Użycie
- Importuj pakiet w kodzie, jeśli potrzebujesz bezpośredniego dostępu:
```dart
import 'package:dot_shorthand_custom_lint/dot_shorthand_custom_lint.dart';
```
- `createPlugin()` jest eksportowane z paczki i wykorzystywane przez narzędzia korzystające z `custom_lint_builder`.

EN
--
Description
- A `custom_lint` rules package for dot-shorthand style checks.
- The plugin entry is implemented in `lib/dot_linter.dart`. 

Installation (from GitHub)
1. Add to your project's `pubspec.yaml`:

```yaml
dependencies:
  dot_shorthand_custom_lint:
    git:
      url: https://github.com/PrzemyslawPluszowy/dot_custom_rule.git
      ref: main
```

2. Run:
```bash
dart pub get
```
3. Restart your IDE/analyzer if necessary.

Usage
- Import the package in your code if needed:
```dart
import 'package:dot_shorthand_custom_lint/dot_shorthand_custom_lint.dart';
```
- `createPlugin()` is exported and will be discovered by tools using `custom_lint_builder`.

Notes
- If you prefer not to use the barrel file, you can import `lib/dot_linter.dart` directly,
  but the conventional package root import is recommended.
