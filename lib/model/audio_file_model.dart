import 'dart:typed_data';

class AudioFileModel {
  final String path;
  final String title;
  final String artist;
  final Uint8List? albumArt;

  AudioFileModel({
    required this.path,
    required this.title,
    required this.artist,
    this.albumArt,
  });

  // Create a copy with updated fields
  AudioFileModel copyWith({
    String? path,
    String? title,
    String? artist,
    Uint8List? albumArt,
  }) {
    return AudioFileModel(
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArt: albumArt ?? this.albumArt,
    );
  }
}
