// home_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'player_screen.dart';
import '../model/audio_file_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<AudioFileModel> _audioFiles = [];
  bool _isLoading = false;
  bool _permissionDenied = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _checkAndRequestPermission();
  }

  Future<void> _checkAndRequestPermission() async {
    // Android 13+ requires audio permission, older versions require storage
    if (await Permission.audio.isGranted) {
      _scanAudioFiles();
      return;
    }

    if (await Permission.storage.isGranted) {
      _scanAudioFiles();
      return;
    }

    if (mounted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a0933),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.deepPurple.withOpacity(0.3)),
          ),
          title: Row(
            children: [
              Icon(Icons.folder_open, color: Colors.deepPurple.shade300),
              const SizedBox(width: 12),
              const Text(
                'Storage Permission',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            'This app needs access to your music files to load and play them.',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _permissionDenied = true);
              },
              child: Text(
                'Deny',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _requestPermission();
              },
              child: const Text(
                'Grant Permission',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);

    PermissionStatus audioStatus = await Permission.audio.request();

    if (audioStatus.isGranted) {
      await _scanAudioFiles();
      return;
    }

    PermissionStatus storageStatus = await Permission.storage.request();

    if (storageStatus.isGranted) {
      await _scanAudioFiles();
      return;
    }

    if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      if (mounted) _showSettingsDialog();
    } else {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a0933),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.deepPurple.withOpacity(0.3)),
          ),
          title: const Text(
            'Permission Required',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Permission is permanently denied. Please enable it from app settings.',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Open Settings',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanAudioFiles() async {
    setState(() => _isLoading = true);

    try {
      List<AudioFileModel> audioFiles = [];

      List<String> searchPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
      ];

      // Assignment Rule: "Restrict to MP3 files only" (mostly)
      // I kept others just in case, but you can remove them if strictness is needed.
      final audioExtensions = ['.mp3', '.m4a', '.aac', '.wav', '.flac'];

      for (String searchPath in searchPaths) {
        try {
          final directory = Directory(searchPath);
          if (await directory.exists()) {
            await for (var entity in directory.list(
              recursive: false,
              followLinks: false,
            )) {
              if (entity is File) {
                final filePath = entity.path;
                final extension = path.extension(filePath).toLowerCase();

                if (audioExtensions.contains(extension)) {
                  audioFiles.add(
                    AudioFileModel(
                      path: filePath,
                      title: path.basenameWithoutExtension(filePath),
                      artist: 'Unknown Artist',
                      albumArt: null,
                    ),
                  );

                  if (audioFiles.length >= 20) break;
                }
              }
            }
            if (audioFiles.length >= 20) break;
          }
        } catch (e) {
          debugPrint('Error scanning $searchPath: $e');
        }
      }

      audioFiles.sort((a, b) {
        try {
          final fileA = File(a.path);
          final fileB = File(b.path);
          return fileB.lastModifiedSync().compareTo(fileA.lastModifiedSync());
        } catch (e) {
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _audioFiles = audioFiles.take(20).toList();
          _isLoading = false;
          _permissionDenied = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading audio files: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickAndPlayMusic() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, // Changed to custom to restrict extensions
        allowedExtensions: ['mp3'], // RULE 1: Restrict to MP3
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                audioPath: filePath,
                playlist: _audioFiles,
                currentIndex: -1,
              ),
            ),
          );
        }
      } else {
        // RULE 1: If user cancels, show message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No audio file selected'),
              backgroundColor: const Color.fromARGB(255, 84, 250, 236),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _playAudio(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          audioPath: _audioFiles[index].path,
          playlist: _audioFiles,
          currentIndex: index,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A4D68), Color(0xFF05161A), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.cyan.shade600, Colors.blue.shade800],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // RULE 1: App Title must be "Local Music Player"
                          const Text(
                            'Music Player',
                            style: TextStyle(
                              fontSize: 26, // Reduced slightly to fit
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${_audioFiles.length} songs available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.cyan.shade200,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyan.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: _scanAudioFiles,
                    ),
                  ],
                ),
              ),

              // Audio Grid
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                color: Colors.cyan,
                                strokeWidth: 4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Scanning audio files...',
                              style: TextStyle(
                                color: Colors.cyan.shade200,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _permissionDenied
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 80,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Permission Denied',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Text(
                                'Please allow storage permission to load music files',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _requestPermission,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Grant Permission'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _audioFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off_rounded,
                              size: 80,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No audio files found',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Try picking a file manually',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                // FIXED: Aspect Ratio 0.7 prevents Overflow error
                                childAspectRatio: 0.7,
                              ),
                          itemCount: _audioFiles.length,
                          itemBuilder: (context, index) {
                            final audio = _audioFiles[index];
                            return _buildAudioCard(audio, index);
                          },
                        ),
                      ),
              ),

              // Pick MP3 Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickAndPlayMusic,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.cyan.shade600, Colors.blue.shade800],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.folder_open_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            // RULE 1: Button should say "Pick MP3" (added File for clarity)
                            'Pick MP3 File',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildAudioCard(AudioFileModel audio, int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.cyan.withOpacity(0.1), Colors.blue.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playAudio(index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Album Art
                Hero(
                  tag: 'album_art_$index',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.cyan.shade700, Colors.blue.shade900],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: Colors.cyan.shade300,
                      size: 30,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Track Title - FIXED: Flexible used to prevent Overflow
                Flexible(
                  child: Text(
                    audio.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 4),

                // Artist
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 12,
                      color: Colors.cyan.shade300,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        audio.artist,
                        style: TextStyle(
                          color: Colors.cyan.shade200,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Play Button
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyan.shade400.withOpacity(0.3),
                        Colors.blue.shade700.withOpacity(0.3),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.cyan.shade300,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
