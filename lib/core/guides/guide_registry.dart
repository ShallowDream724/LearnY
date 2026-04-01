class GuideDefinition {
  const GuideDefinition({
    required this.id,
    required this.version,
    required this.title,
  });

  final String id;
  final String version;
  final String title;
}

abstract final class GuideRegistry {
  static const GuideDefinition loginAutoRelogin = GuideDefinition(
    id: 'login.auto_relogin',
    version: '1',
    title: '建议开启自动重新登录',
  );

  static GuideDefinition byId(String id) {
    return switch (id) {
      'login.auto_relogin' => loginAutoRelogin,
      _ => throw ArgumentError.value(id, 'id', 'Unknown guide id'),
    };
  }
}
