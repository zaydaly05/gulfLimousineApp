/// Pull-to-refresh handler for screens backed by live Firestore streams.
///
/// The data already updates on its own, so the gesture only needs to show
/// the refresh spinner briefly as feedback.
Future<void> liveDataRefresh() =>
    Future<void>.delayed(const Duration(milliseconds: 600));
