---
paths:
  - "lib/**"
  - "test/**"
---

# Dart & Flutter Rules for better_player_plus

1. **Pub.dev Score (Target: 160/160)**:
   - Zero static analysis warnings (`analysis_options.yaml` with `analysis_lints`).
   - Prefer collection elements (`if` elements) over ternary expressions where applicable (`prefer_if_elements_to_conditional_expressions`).
   - All public APIs must have descriptive doc comments (`///`).

2. **Dependencies & Compatibility**:
   - Keep minimum Flutter constraint at `flutter: ">=3.41.0"` unless an explicit major version upgrade is approved.
   - Avoid bringing in unmaintained external dependencies (inline utilities if small, like visibility detection, to prevent dependency solver conflicts).

3. **Controller & State Lifecycle**:
   - Any controller created inside a widget must be safely disposed in the widget state's `dispose()` method.
   - Guard against calling `setState()` or event channel methods after the widget or controller is disposed.
   - Guard list video players against race conditions when fast scrolling or recycling views.
