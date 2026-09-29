import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:apivideo_live_stream/apivideo_live_stream.dart';

import '../core/theme.dart';
import '../providers/gateway_provider.dart';

class CameraBroadcasterScreen extends StatefulWidget {
  final bool isTabActive;

  const CameraBroadcasterScreen({Key? key, this.isTabActive = true}) : super(key: key);

  @override
  State<CameraBroadcasterScreen> createState() => _CameraBroadcasterScreenState();
}

class _CameraBroadcasterScreenState extends State<CameraBroadcasterScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  ApiVideoLiveStreamController? _controller;
  bool _isInitialized = false;
  bool _isStreaming = false;
  bool _isMuted = false;
  bool _isFrontCamera = false;
  String? _initError;

  // Stream Configuration
  String _streamKey = 'mobile_cam';
  Resolution _resolution = Resolution.RESOLUTION_720;
  int _bitrate = 3500000; // 3.5 Mbps in bps
  int _fps = 30;

  // Duration & Telemetry
  Timer? _durationTimer;
  int _elapsedSeconds = 0;
  double _simAudioLevelL = -24.0;
  double _simAudioLevelR = -25.0;
  Timer? _audioSimTimer;

  // Pulse animation for Tally
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController);

    _initCamera();
  }

  @override
  void didUpdateWidget(covariant CameraBroadcasterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive != oldWidget.isTabActive) {
      if (widget.isTabActive) {
        if (_controller == null || !_isInitialized) {
          _initCamera();
        } else {
          _controller?.startPreview();
        }
      } else {
        if (!_isStreaming) {
          _controller?.stopPreview();
        }
      }
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initError = null;
      _isInitialized = false;
    });

    try {
      final ctrl = ApiVideoLiveStreamController(
        initialAudioConfig: AudioConfig(
          bitrate: 128000,
          channel: Channel.stereo,
          sampleRate: SampleRate.kHz_44_1,
          enableEchoCanceler: true,
          enableNoiseSuppressor: true,
        ),
        initialVideoConfig: VideoConfig(
          bitrate: _bitrate,
          resolution: _resolution,
          fps: _fps,
        ),
        initialCameraPosition: _isFrontCamera ? CameraPosition.front : CameraPosition.back,
        onConnectionSuccess: () {
          if (!mounted) return;
          setState(() {
            _isStreaming = true;
            _elapsedSeconds = 0;
          });
          _startDurationTimer();
          _startAudioMonitoring();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: MakasnaTheme.green,
              content: Text(
                'LIVE ON AIR: Broadcasting to Makasna Gateway ($_streamKey)',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
        onConnectionFailed: (error) {
          if (!mounted) return;
          setState(() => _isStreaming = false);
          _stopDurationTimer();
          _stopAudioMonitoring();
          _showErrorDialog('Connection Failed', error);
        },
        onDisconnection: () {
          if (!mounted) return;
          setState(() => _isStreaming = false);
          _stopDurationTimer();
          _stopAudioMonitoring();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: MakasnaTheme.amber,
              content: Text(
                'Broadcast Disconnected from Gateway',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isStreaming = false);
          _stopDurationTimer();
          _stopAudioMonitoring();
          _showErrorDialog('Encoder Error', error.toString());
        },
      );

      await ctrl.initialize();

      if (mounted) {
        setState(() {
          _controller = ctrl;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _isInitialized = false;
        });
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _startAudioMonitoring() {
    _audioSimTimer?.cancel();
    _audioSimTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      if (_isMuted) {
        setState(() {
          _simAudioLevelL = -60.0;
          _simAudioLevelR = -60.0;
        });
      } else {
        // Dynamic audio ballistics
        final base = -20.0 + (t.tick % 10) * 1.2;
        setState(() {
          _simAudioLevelL = base - (t.tick % 3);
          _simAudioLevelR = base - ((t.tick + 1) % 3);
        });
      }
    });
  }

  void _stopAudioMonitoring() {
    _audioSimTimer?.cancel();
    _audioSimTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      if (!_isStreaming) {
        _controller?.stop();
      }
    } else if (state == AppLifecycleState.resumed) {
      _controller?.startPreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDurationTimer();
    _stopAudioMonitoring();
    _pulseController.dispose();
    _controller?.stop();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleBroadcast() async {
    if (_controller == null || !_isInitialized) return;

    final gateway = context.read<GatewayProvider>();
    final serverHost = gateway.config.host.isEmpty ? '139.190.97.109' : gateway.config.host;
    // RTMP Ingest port on MediaMTX is 1935
    final rtmpUrl = 'rtmp://$serverHost:1935/';

    if (_isStreaming) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: MakasnaTheme.panel,
          title: const Text('STOP LIVE BROADCAST?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to stop pushing camera feed ($_streamKey) to the broadcast gateway?',
            style: const TextStyle(color: MakasnaTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CONTINUE STREAMING', style: TextStyle(color: MakasnaTheme.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MakasnaTheme.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('STOP BROADCAST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await _controller?.stopStreaming();
          setState(() => _isStreaming = false);
          _stopDurationTimer();
          _stopAudioMonitoring();
        } catch (e) {
          _showErrorDialog('Stop Error', e.toString());
        }
      }
    } else {
      try {
        await _controller?.startStreaming(
          streamKey: _streamKey,
          url: rtmpUrl,
        );
      } catch (e) {
        _showErrorDialog('Failed to Start Broadcast', e.toString());
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_controller == null || !_isInitialized) return;
    try {
      await _controller?.switchCamera();
      setState(() => _isFrontCamera = !_isFrontCamera);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to switch camera: $e')),
      );
    }
  }

  Future<void> _toggleMute() async {
    if (_controller == null || !_isInitialized) return;
    try {
      await _controller?.toggleMute();
      final muted = await _controller?.isMuted ?? false;
      setState(() => _isMuted = muted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(_isMuted ? 'Microphone MUTED' : 'Microphone ACTIVE (Unmuted)'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle mute: $e')),
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MakasnaTheme.panel,
        title: Text(title, style: const TextStyle(color: MakasnaTheme.red, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: MakasnaTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DISMISS', style: TextStyle(color: MakasnaTheme.cyan)),
          ),
        ],
      ),
    );
  }

  String _formatTimecode(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showConfigurationModal() {
    final gateway = context.read<GatewayProvider>();
    final serverHost = gateway.config.host.isEmpty ? '139.190.97.109' : gateway.config.host;
    final srtIngestUrl = 'srt://$serverHost:8890?streamid=publish:$_streamKey&latency=2000000';
    final rtmpIngestUrl = 'rtmp://$serverHost:1935/$_streamKey';
    final srtReadUrl = 'srt://$serverHost:8890?streamid=read:$_streamKey';
    final hlsPreviewUrl = 'http://$serverHost:8888/$_streamKey/index.m3u8';

    final textController = TextEditingController(text: _streamKey);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MakasnaTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Modal Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: MakasnaTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.tune, color: MakasnaTheme.cyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'BROADCAST CONFIGURATION & LARIX SETUP',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: MakasnaTheme.textDim, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  color: MakasnaTheme.panelElevated,
                  child: const TabBar(
                    indicatorColor: MakasnaTheme.cyan,
                    labelColor: MakasnaTheme.cyan,
                    unselectedLabelColor: MakasnaTheme.textDim,
                    tabs: [
                      Tab(text: 'POCKET BROADCASTER'),
                      Tab(text: 'LARIX BROADCASTER GUIDE'),
                    ],
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: POCKET BROADCASTER SETTINGS
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            'STREAM IDENTIFIER (STREAM ID)',
                            style: TextStyle(color: MakasnaTheme.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: textController,
                            enabled: !_isStreaming,
                            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: 'e.g. mobile_cam or cam1',
                              hintStyle: const TextStyle(color: MakasnaTheme.textDim),
                              prefixIcon: const Icon(Icons.videocam, color: MakasnaTheme.cyan, size: 18),
                              suffixIcon: _isStreaming
                                  ? const Tooltip(
                                      message: 'Locked while live',
                                      child: Icon(Icons.lock, color: MakasnaTheme.red, size: 16),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Target Resolution
                          const Text(
                            'VIDEO ENCODING RESOLUTION',
                            style: TextStyle(color: MakasnaTheme.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildResolutionOption(
                                '1080p',
                                '1920x1080',
                                Resolution.RESOLUTION_1080,
                                modalCtx,
                                setModalState,
                              ),
                              const SizedBox(width: 8),
                              _buildResolutionOption(
                                '720p (Rec.)',
                                '1280x720',
                                Resolution.RESOLUTION_720,
                                modalCtx,
                                setModalState,
                              ),
                              const SizedBox(width: 8),
                              _buildResolutionOption(
                                '480p',
                                '854x480',
                                Resolution.RESOLUTION_480,
                                modalCtx,
                                setModalState,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Target Bitrate
                          const Text(
                            'TARGET VIDEO BITRATE',
                            style: TextStyle(color: MakasnaTheme.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildBitrateChip('2.0 Mbps (Cellular Low)', 2000000, modalCtx, setModalState),
                              _buildBitrateChip('3.5 Mbps (Standard Live)', 3500000, modalCtx, setModalState),
                              _buildBitrateChip('5.0 Mbps (High Quality)', 5000000, modalCtx, setModalState),
                              _buildBitrateChip('8.0 Mbps (Broadcast Master)', 8000000, modalCtx, setModalState),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // FPS
                          const Text(
                            'FRAME RATE',
                            style: TextStyle(color: MakasnaTheme.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: _fps == 30 ? MakasnaTheme.cyanDim : null,
                                    side: BorderSide(color: _fps == 30 ? MakasnaTheme.cyan : MakasnaTheme.border),
                                  ),
                                  onPressed: _isStreaming
                                      ? null
                                      : () => setModalState(() => _fps = 30),
                                  child: const Text('30 FPS (Standard Broadcast)'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: _fps == 60 ? MakasnaTheme.cyanDim : null,
                                    side: BorderSide(color: _fps == 60 ? MakasnaTheme.cyan : MakasnaTheme.border),
                                  ),
                                  onPressed: _isStreaming
                                      ? null
                                      : () => setModalState(() => _fps = 60),
                                  child: const Text('60 FPS (High Motion)'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MakasnaTheme.cyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isStreaming
                                ? null
                                : () async {
                                    final newKey = textController.text.trim();
                                    if (newKey.isNotEmpty) {
                                      setState(() {
                                        _streamKey = newKey;
                                      });
                                    }
                                    Navigator.pop(ctx);
                                    await _initCamera();
                                  },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('APPLY SETTINGS & RE-INITIALIZE', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),

                      // TAB 2: LARIX BROADCASTER FIELD REFERENCE
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: MakasnaTheme.cyanDim,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: MakasnaTheme.cyan.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline, color: MakasnaTheme.cyan, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Using Larix Broadcaster on another mobile phone or tablet? Use the parameters below to stream directly into this Makasna Gateway.',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Parameter 1: SRT Ingest URL (Larix Primary)
                          _buildCopyableField(
                            '1. LARIX PRIMARY: SRT PUBLISH URL',
                            srtIngestUrl,
                            'In Larix Broadcaster: Settings > Connections > New Connection > SRT Caller',
                          ),
                          const SizedBox(height: 12),

                          // Parameter 2: RTMP Ingest URL
                          _buildCopyableField(
                            '2. ALTERNATIVE: RTMP PUSH URL',
                            rtmpIngestUrl,
                            'In Larix or other RTMP encoders: Set URL and stream key',
                          ),
                          const SizedBox(height: 12),

                          // Parameter 3: Downstream Receiver URL
                          _buildCopyableField(
                            '3. DOWNSTREAM RECEIVER (vMix / OBS / Playout)',
                            srtReadUrl,
                            'Use this URL on master control switchers to ingest this phone camera stream',
                          ),
                          const SizedBox(height: 12),

                          // Parameter 4: Web HLS Live Preview
                          _buildCopyableField(
                            '4. WEB HLS PLAYLIST URL',
                            hlsPreviewUrl,
                            'Low latency fMP4 HLS manifest for browsers and web players',
                          ),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: MakasnaTheme.panelInput,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: MakasnaTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'RECOMMENDED LARIX ENCODER CONFIGURATION:',
                                  style: TextStyle(color: MakasnaTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 6),
                                Text('• Video Codec: H.264 (Baseline or Main Profile)', style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12)),
                                Text('• Bitrate: 3500 kbps (CBR / Constant Bitrate)', style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12)),
                                Text('• Keyframe Interval: 1.0 second or 2.0 seconds', style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12)),
                                Text('• SRT Latency Buffer: 2000 ms (TSBPD)', style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12)),
                                Text('• Audio Codec: AAC 128 kbps, 44.1 kHz or 48 kHz', style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResolutionOption(String label, String sub, Resolution res, BuildContext ctx, StateSetter setModalState) {
    final isSelected = _resolution == res;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? MakasnaTheme.cyanDim : null,
          side: BorderSide(color: isSelected ? MakasnaTheme.cyan : MakasnaTheme.border),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: _isStreaming ? null : () => setModalState(() => _resolution = res),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isSelected ? MakasnaTheme.cyan : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: MakasnaTheme.textDim, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildBitrateChip(String label, int bps, BuildContext ctx, StateSetter setModalState) {
    final isSelected = _bitrate == bps;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      selected: isSelected,
      selectedColor: MakasnaTheme.cyan,
      backgroundColor: MakasnaTheme.panelInput,
      side: BorderSide(color: isSelected ? MakasnaTheme.cyan : MakasnaTheme.border),
      onSelected: _isStreaming ? null : (selected) {
        if (selected) {
          setModalState(() => _bitrate = bps);
        }
      },
    );
  }

  Widget _buildCopyableField(String label, String value, String hint) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MakasnaTheme.panelInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MakasnaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: MakasnaTheme.textDim, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: MakasnaTheme.cyan, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied: $value')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(hint, style: const TextStyle(color: MakasnaTheme.textDim, fontSize: 10)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gateway = context.watch<GatewayProvider>();
    final serverHost = gateway.config.host.isEmpty ? '139.190.97.109' : gateway.config.host;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF090A0F),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: MakasnaTheme.cyan.withOpacity(0.5)),
              ),
              child: Center(
                child: Image.asset('assets/images/logo.png', width: 14, height: 14, errorBuilder: (_, __, ___) => const Icon(Icons.videocam, color: MakasnaTheme.cyan, size: 12)),
              ),
            ),
            const SizedBox(width: 8),
            const Text('CAMERA BROADCASTER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        actions: [
          // Tally Lamp
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _isStreaming ? MakasnaTheme.redDim : MakasnaTheme.cyanDim,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _isStreaming ? MakasnaTheme.red : MakasnaTheme.cyan.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isStreaming ? MakasnaTheme.red : MakasnaTheme.cyan,
                      boxShadow: _isStreaming
                          ? [
                              BoxShadow(
                                color: MakasnaTheme.red.withOpacity(_pulseAnimation.value),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isStreaming ? 'ON AIR' : 'STANDBY',
                  style: TextStyle(
                    color: _isStreaming ? MakasnaTheme.red : MakasnaTheme.cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.tune, color: MakasnaTheme.cyan),
            tooltip: 'Encoder Settings & Larix Guide',
            onPressed: _showConfigurationModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // CAMERA VIEWFINDER (CONFIDENCE MONITOR)
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isStreaming ? MakasnaTheme.red : MakasnaTheme.border,
                  width: _isStreaming ? 2 : 1,
                ),
                boxShadow: _isStreaming
                    ? [
                        BoxShadow(
                          color: MakasnaTheme.red.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video Texture
                    if (_isInitialized && _controller != null)
                      Center(
                        child: ApiVideoCameraPreview(
                          controller: _controller!,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (_initError != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off, color: MakasnaTheme.red, size: 40),
                              const SizedBox(height: 10),
                              const Text('Camera Sensor Initialization Error', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(
                                _initError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: MakasnaTheme.textDim, fontSize: 11),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: MakasnaTheme.cyan, foregroundColor: Colors.black),
                                onPressed: _initCamera,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('RETRY CAMERA SENSOR'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(color: MakasnaTheme.cyan),
                            SizedBox(height: 12),
                            Text(
                              'INITIALIZING CAMERA SENSOR...',
                              style: TextStyle(color: MakasnaTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),

                    // FLOATING BROADCAST OSD OVERLAYS
                    // Top Left: Stream Specs Pill
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isStreaming ? MakasnaTheme.green : MakasnaTheme.cyan,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_resolution.name.replaceAll('RESOLUTION_', '')}p · ${_fps}FPS · ${(_bitrate / 1000000).toStringAsFixed(1)}M',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Right: Monospace Timecode
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _isStreaming ? MakasnaTheme.red : Colors.white24),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isStreaming ? Icons.fiber_manual_record : Icons.timer,
                              size: 12,
                              color: _isStreaming ? MakasnaTheme.red : MakasnaTheme.textDim,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimecode(_elapsedSeconds),
                              style: TextStyle(
                                color: _isStreaming ? Colors.white : MakasnaTheme.textDim,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Viewfinder Action Controls (Right Column)
                    Positioned(
                      right: 10,
                      bottom: 48,
                      child: Column(
                        children: [
                          // Switch Camera (Flip)
                          Material(
                            color: Colors.black.withOpacity(0.65),
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 20),
                              tooltip: 'Flip Camera',
                              onPressed: _switchCamera,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Mute / Unmute Mic
                          Material(
                            color: (_isMuted ? MakasnaTheme.red : Colors.black).withOpacity(0.65),
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.white : MakasnaTheme.cyan, size: 20),
                              tooltip: _isMuted ? 'Unmute Mic' : 'Mute Mic',
                              onPressed: _toggleMute,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Viewfinder Bottom Overlay (Stream info & VU Meter)
                    Positioned(
                      left: 10,
                      right: 70,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Target Stream Label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              'STREAM: $_streamKey  |  $serverHost',
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Dual Audio VU Meter Bars
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              children: [
                                _buildMiniVuBar('CH1', _simAudioLevelL),
                                const SizedBox(height: 3),
                                _buildMiniVuBar('CH2', _simAudioLevelR),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BOTTOM TRANSPORT CONTROL BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: MakasnaTheme.panel,
              border: Border(top: BorderSide(color: MakasnaTheme.border)),
            ),
            child: Column(
              children: [
                // Big Tactile Broadcast Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isStreaming ? MakasnaTheme.red : MakasnaTheme.cyan,
                      foregroundColor: _isStreaming ? Colors.white : Colors.black,
                      elevation: _isStreaming ? 8 : 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _isInitialized ? _toggleBroadcast : null,
                    icon: Icon(_isStreaming ? Icons.stop_circle : Icons.videocam, size: 22),
                    label: Text(
                      _isStreaming ? 'STOP LIVE BROADCAST' : 'START LIVE BROADCAST',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Row (Quick Settings & Info)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isStreaming ? '● STREAMING LIVE (RTMP/SRT)' : 'READY TO BROADCAST',
                      style: TextStyle(
                        color: _isStreaming ? MakasnaTheme.red : MakasnaTheme.textDim,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    InkWell(
                      onTap: _showConfigurationModal,
                      child: Row(
                        children: const [
                          Icon(Icons.tune, color: MakasnaTheme.cyan, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Encoder & Larix Setup',
                            style: TextStyle(color: MakasnaTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniVuBar(String channel, double levelDbfs) {
    // Clamp -60 to 0 dBFS
    final normalized = ((levelDbfs + 60.0) / 60.0).clamp(0.0, 1.0);
    final isClip = levelDbfs >= -0.5;

    return Row(
      children: [
        Text(
          channel,
          style: const TextStyle(color: MakasnaTheme.textDim, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: normalized,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF10B981), // Green
                      Color(0xFFF59E0B), // Amber
                      Color(0xFFEF4444), // Red
                    ],
                    stops: [0.65, 0.85, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isClip ? 'CLIP' : '${levelDbfs.toStringAsFixed(0)} dB',
          style: TextStyle(
            color: isClip ? MakasnaTheme.red : MakasnaTheme.textDim,
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
