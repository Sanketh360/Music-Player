import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  // Load and play audio file
  Future<void> loadAudio(String filePath) async {
    try {
      await _audioPlayer.setFilePath(filePath);
    } catch (e) {
      throw Exception('Failed to load audio: $e');
    }
  }

  // Play audio
  Future<void> play() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      throw Exception('Failed to play audio: $e');
    }
  }

  // Pause audio
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      throw Exception('Failed to pause audio: $e');
    }
  }

  // Stop audio
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      throw Exception('Failed to stop audio: $e');
    }
  }

  // Seek to position
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      throw Exception('Failed to seek: $e');
    }
  }

  // Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await pause();
    } else {
      await play();
    }
  }

  // Get audio metadata
  Future<AudioMetadata> getMetadata(String filePath) async {
    try {
      final file = File(filePath);
      final metadata = await readMetadata(file, getImage: true);

      return AudioMetadata(
        title: metadata.title ?? _getFileNameFromPath(filePath),
        artist: metadata.artist ?? 'Unknown Artist',
        album: metadata.album ?? 'Unknown Album',
        albumArt: metadata.pictures.isNotEmpty
            ? metadata.pictures.first.bytes
            : null,
      );
    } catch (e) {
      // Return default metadata if extraction fails
      return AudioMetadata(
        title: _getFileNameFromPath(filePath),
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        albumArt: null,
      );
    }
  }

  // Extract file name from path
  String _getFileNameFromPath(String path) {
    return path.split('/').last.replaceAll('.mp3', '').replaceAll('_', ' ');
  }

  // Get current position
  Duration get currentPosition => _audioPlayer.position;

  // Get total duration
  Duration? get totalDuration => _audioPlayer.duration;

  // Check if playing
  bool get isPlaying => _audioPlayer.playing;

  // Dispose audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}

// Audio Metadata Model
class AudioMetadata {
  final String title;
  final String artist;
  final String album;
  final Uint8List? albumArt;

  AudioMetadata({
    required this.title,
    required this.artist,
    required this.album,
    this.albumArt,
  });
}
