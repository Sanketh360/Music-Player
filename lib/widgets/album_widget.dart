import 'dart:typed_data';
import 'package:flutter/material.dart';

class AlbumArtWidget extends StatelessWidget {
  final Uint8List? albumArt;
  final double size;
  final bool isPlaying;

  const AlbumArtWidget({
    super.key,
    required this.albumArt,
    this.size = 280,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'album_art',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withOpacity(isPlaying ? 0.5 : 0.3),
              blurRadius: isPlaying ? 40 : 30,
              spreadRadius: isPlaying ? 8 : 5,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Album Art or Placeholder
              albumArt != null
                  ? Image.memory(
                      albumArt!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.cyan.shade700, Colors.blue.shade900],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: size * 0.4,
                          color: Colors.cyan.shade300,
                        ),
                      ),
                    ),

              // Animated Overlay when playing
              if (isPlaying)
                AnimatedOpacity(
                  opacity: 0.1,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.cyan.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
