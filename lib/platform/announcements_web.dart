import '../features/announcements/announcements.dart';

/// Browsers get no announcements (specs/015 edge case "Web app").
AnnouncementsPlatform announcementsPlatform({
  required String Function() channelName,
}) => const NoAnnouncements();
