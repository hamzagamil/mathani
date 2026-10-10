## What and why

<!-- One or two sentences. Link the spec task IDs (e.g. T030). -->

## Checks

- [ ] `flutter analyze` and `flutter test` pass
- [ ] Verified on Android and on the iOS simulator (CI integration jobs green)
- [ ] Size check passed in CI. If the size grew by more than 1 MB, explain why here and add the
  `size-approved` label.

### Performance (required when this touches startup, navigation, lists, images or dependencies)

| Metric | Budget | Before | After | Device |
| --- | --- | --- | --- | --- |
| Cold start to readable Mushaf | ≤ 2 s | | | |
| Janky frames while paging 50 pages | 0 | | | |
| Search result time | ≤ 1 s | | | |

### New dependency? (constitution IV)

<!-- What it replaces, its size cost, and why platform APIs or existing code are not enough. -->
