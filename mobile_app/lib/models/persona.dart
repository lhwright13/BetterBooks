class Persona {
  final String name;
  final String displayName;
  final String description;
  final String voice;
  final Map<String, dynamic> voiceConfig;

  Persona({
    required this.name,
    required this.displayName,
    required this.description,
    required this.voice,
    required this.voiceConfig,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      voice: json['voice'] ?? 'en-US-Neural2-C',
      voiceConfig: json['voice_config'] ?? {},
    );
  }
}