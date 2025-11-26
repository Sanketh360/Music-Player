import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;
import '../widgets/album_widget.dart';
import '../widgets/play_pause_button.dart';
import '../widgets/seek_bar_widget.dart';
import '../services/audio_service.dart';
import '../model/audio_file_model.dart';

class PlayerScreen extends StatefulWidget {
  final String audioPath;
  final List<AudioFileModel> playlist;
  final int currentIndex;

  const PlayerScreen({
    super.key,
    required this.audioPath,
    required this.playlist,
    required this.currentIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late AudioService _audioService;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  String _title = 'Unknown Track';
  String _artist = 'Unknown Artist';
  AudioMetadata? _metadata;
  String? _currentAudioPath;
  late int _currentIndex;
  bool _isShuffleOn = false;
  List<int> _shuffledIndices = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _currentAudioPath = widget.audioPath;
    _currentIndex = widget.currentIndex;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _initAudio();
    _setupListeners();
  }

  Future<void> _initAudio() async {
    setState(() => _isLoading = true);

    try {
      _metadata = await _audioService.getMetadata(_currentAudioPath!);

      setState(() {
        _title = _metadata!.title;
        _artist = _metadata!.artist;
      });

      await _audioService.loadAudio(_currentAudioPath!);

      setState(() => _isLoading = false);
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Could not play this file')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _setupListeners() {
    _audioService.durationStream.listen((duration) {
      if (duration != null) {
        setState(() => _duration = duration);
      }
    });

    _audioService.positionStream.listen((position) {
      setState(() => _position = position);
    });

    _audioService.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });

      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });
  }

  Future<void> _togglePlayPause() async {
    await _audioService.togglePlayPause();
  }

  Future<void> _playNext() async {
    // If no playlist or manually picked file, try to switch to playlist
    if (widget.playlist.isEmpty) {
      // No songs in playlist, just stop
      setState(() {
        _position = Duration.zero;
        _isPlaying = false;
      });
      await _audioService.seek(Duration.zero);
      await _audioService.pause();
      return;
    }

    // If currently playing a manually picked file (index == -1)
    // Switch to first song in playlist
    if (_currentIndex == -1) {
      await _loadTrack(0);
      return;
    }

    int nextIndex;

    if (_isShuffleOn) {
      if (_shuffledIndices.isEmpty) {
        _generateShuffledIndices();
      }
      final currentShuffledPosition = _shuffledIndices.indexOf(_currentIndex);
      final nextShuffledPosition =
          (currentShuffledPosition + 1) % _shuffledIndices.length;
      nextIndex = _shuffledIndices[nextShuffledPosition];
    } else {
      nextIndex = (_currentIndex + 1) % widget.playlist.length;
    }

    await _loadTrack(nextIndex);
  }

  Future<void> _playPrevious() async {
    // If no playlist, can't go to previous
    if (widget.playlist.isEmpty) {
      // Just restart current song
      await _audioService.seek(Duration.zero);
      return;
    }

    // If position > 3 seconds, just restart current song
    if (_position.inSeconds > 3) {
      await _audioService.seek(Duration.zero);
      return;
    }

    // If currently playing a manually picked file (index == -1)
    // Switch to last song in playlist
    if (_currentIndex == -1) {
      await _loadTrack(widget.playlist.length - 1);
      return;
    }

    int previousIndex;

    if (_isShuffleOn) {
      if (_shuffledIndices.isEmpty) {
        _generateShuffledIndices();
      }
      final currentShuffledPosition = _shuffledIndices.indexOf(_currentIndex);
      final previousShuffledPosition =
          (currentShuffledPosition - 1 + _shuffledIndices.length) %
          _shuffledIndices.length;
      previousIndex = _shuffledIndices[previousShuffledPosition];
    } else {
      previousIndex =
          (_currentIndex - 1 + widget.playlist.length) % widget.playlist.length;
    }

    await _loadTrack(previousIndex);
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffleOn = !_isShuffleOn;
      if (_isShuffleOn) {
        _generateShuffledIndices();
      }
    });
  }

  void _generateShuffledIndices() {
    _shuffledIndices = List.generate(widget.playlist.length, (index) => index);
    _shuffledIndices.shuffle();
  }

  Future<void> _loadTrack(int index) async {
    await _audioService.stop();
    _fadeController.reset();

    setState(() {
      _currentIndex = index;
      _currentAudioPath = widget.playlist[index].path;
    });

    await _initAudio();
    await _audioService.play();
  }

  Future<void> _pickNewFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        await _audioService.stop();
        _currentAudioPath = result.files.single.path;
        _currentIndex = -1;
        _fadeController.reset();
        await _initAudio();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    _fadeController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if navigation buttons should be enabled
    bool canNavigate = widget.playlist.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Now Playing',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.folder_open_rounded, size: 18),
            ),
            onPressed: _pickNewFile,
            tooltip: 'Pick new file',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A4D68),
                    Color(0xFF05161A),
                    Color(0xFF000000),
                  ],
                ),
              ),
              child: Center(
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
                      'Loading audio...',
                      style: TextStyle(
                        color: Colors.cyan.shade200,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A4D68),
                    Color(0xFF05161A),
                    Color(0xFF000000),
                  ],
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // Album Art (Reduced Size)
                        AlbumArtWidget(
                          albumArt: _metadata?.albumArt,
                          size: 200,
                          isPlaying: _isPlaying,
                        ),

                        const SizedBox(height: 20),

                        // Track Info Section (Reduced Padding)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.cyan.withOpacity(0.1),
                                Colors.blue.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.cyan.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 16,
                                    color: Colors.cyan.shade300,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _artist,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.cyan.shade200,
                                        letterSpacing: 0.3,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              // Show playlist info if manually picked file
                              if (_currentIndex == -1 &&
                                  widget.playlist.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Press Next to play from playlist (${widget.playlist.length} songs)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.cyan.shade300,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Waveform Visualizer
                        _buildWaveform(),

                        const SizedBox(height: 20),

                        // Seek Bar
                        SeekBarWidget(
                          position: _position,
                          duration: _duration,
                          onChanged: (position) async {
                            await _audioService.seek(position);
                          },
                        ),

                        const SizedBox(height: 20),

                        // Control Buttons Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Shuffle Button - only enabled when playlist is available
                            _buildControlButton(
                              icon: Icons.shuffle_rounded,
                              onPressed: canNavigate ? _toggleShuffle : null,
                              isActive: _isShuffleOn && canNavigate,
                            ),

                            // Previous Button - enabled when playlist exists
                            _buildControlButton(
                              icon: Icons.skip_previous_rounded,
                              onPressed: canNavigate ? _playPrevious : null,
                              size: 45,
                            ),

                            // Play/Pause Button - always enabled
                            PlayPauseButton(
                              isPlaying: _isPlaying,
                              onPressed: _togglePlayPause,
                              size: 65,
                            ),

                            // Next Button - enabled when playlist exists
                            _buildControlButton(
                              icon: Icons.skip_next_rounded,
                              onPressed: canNavigate ? _playNext : null,
                              size: 45,
                            ),

                            // Repeat placeholder - only enabled when playlist is available
                            _buildControlButton(
                              icon: Icons.repeat_rounded,
                              onPressed: canNavigate ? () {} : null,
                              isActive: false,
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(40, (index) {
              final progress = (_waveController.value + (index / 40)) % 1.0;
              final height = _isPlaying
                  ? (math.sin(progress * 2 * math.pi) * 0.5 + 0.5) * 40 + 10
                  : 10.0;

              return Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.cyan.shade700, Colors.cyan.shade300],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: _isPlaying
                      ? [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool isActive = false,
    double size = 40,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [Colors.cyan.shade400, Colors.blue.shade700],
              )
            : null,
        color: isActive ? null : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.cyan.shade300 : Colors.cyan.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(
            icon,
            color: onPressed == null ? Colors.grey.shade600 : Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
