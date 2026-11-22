/// Browsers have no widgets (specs/017 Edge Cases): every call does nothing.
class HomeWidgets {
  const HomeWidgets();
  Future<void> update(String snapshot, String watch) async {}
  Future<List<String>> placed() async => const [];
  Future<void> clear() async {}
}
