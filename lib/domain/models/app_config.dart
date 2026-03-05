/// Application configuration carrying SDUI layouts and vote form schemas.
class AppConfig {
  final int schemaVersion;
  final Map<String, dynamic>? dashboardLayout; // SDUI JSON for dashboard
  final Map<String, dynamic>? voteFormSchema; // SDUI JSON for vote form
  final DateTime fetchedAt;

  const AppConfig({
    required this.schemaVersion,
    this.dashboardLayout,
    this.voteFormSchema,
    required this.fetchedAt,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      schemaVersion: json['schemaVersion'] as int,
      dashboardLayout: json['dashboardLayout'] as Map<String, dynamic>?,
      voteFormSchema: json['voteFormSchema'] as Map<String, dynamic>?,
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.parse(json['fetchedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        if (dashboardLayout != null) 'dashboardLayout': dashboardLayout,
        if (voteFormSchema != null) 'voteFormSchema': voteFormSchema,
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}
