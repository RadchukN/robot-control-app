class ProjectManifest {
  const ProjectManifest({
    required this.name,
    required this.version,
    required this.rootPath,
    this.pythonVersion,
  });

  factory ProjectManifest.fromJson(Map<String, dynamic> json) =>
      ProjectManifest(
        name: json['name'] as String,
        version: json['version'] as String,
        rootPath: json['root_path'] as String,
        pythonVersion: json['python_version'] as String?,
      );

  final String name;
  final String version;
  final String rootPath;
  final String? pythonVersion;
}
