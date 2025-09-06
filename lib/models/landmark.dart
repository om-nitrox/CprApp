class Landmark {
  final double x;
  final double y;
  final double z;
  final double visibility;

  Landmark({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      x: json['x']?.toDouble() ?? 0.0,
      y: json['y']?.toDouble() ?? 0.0,
      z: json['z']?.toDouble() ?? 0.0,
      visibility: json['visibility']?.toDouble() ?? 0.0,
    );
  }
}

class PoseData {
  final List<Landmark> landmarks;
  final DateTime timestamp;

  PoseData({required this.landmarks, required this.timestamp});
}
