import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/server_config.dart';
import '../providers/gateway_provider.dart';
import '../services/preferences_service.dart';
import 'home_navigation_screen.dart';

class WelcomeServerScreen extends StatefulWidget {
  final bool isSwitching;

  const WelcomeServerScreen({Key? key, this.isSwitching = false}) : super(key: key);

  @override
  State<WelcomeServerScreen> createState() => _WelcomeServerScreenState();
}

class _WelcomeServerScreenState extends State<WelcomeServerScreen> with SingleTickerProviderStateMixin {
  final PreferencesService _prefs = PreferencesService();
  late TabController _tabController;

  late TextEditingController _hostController;
  late TextEditingController _httpPortController;
  late TextEditingController _srtPortController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  bool _useHttps = false;
  bool _obscurePassword = true;
  bool _rememberSession = true;

  bool _isTesting = false;
  String? _testMessage;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final currentConfig = context.read<GatewayProvider>().config;
    _hostController = TextEditingController(text: currentConfig.host);
    _httpPortController = TextEditingController(text: currentConfig.httpPort.toString());
    _srtPortController = TextEditingController(text: currentConfig.srtPort.toString());
    _userController = TextEditingController(text: currentConfig.username.isNotEmpty ? currentConfig.username : 'admin');
    _passController = TextEditingController(text: currentConfig.password);
    _useHttps = currentConfig.useHttps;

    // Listen to changes so Tab 2 (Broadcast Guide) updates URLs dynamically in real-time
    _hostController.addListener(_onFormChanged);
    _httpPortController.addListener(_onFormChanged);
    _srtPortController.addListener(_onFormChanged);

    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final remember = await _prefs.loadRememberSession();
    final saved = await _prefs.loadServerConfig();
    if (!mounted) return;
    setState(() {
      _rememberSession = remember;
      if (_hostController.text.trim().isEmpty && saved.host.trim().isNotEmpty) {
        _hostController.text = saved.host;
        _httpPortController.text = saved.httpPort.toString();
        _srtPortController.text = saved.srtPort.toString();
        if (saved.username.isNotEmpty) _userController.text = saved.username;
        if (saved.password.isNotEmpty) _passController.text = saved.password;
        _useHttps = saved.useHttps;
      }
    });
  }

  void _onFormChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostController.removeListener(_onFormChanged);
    _httpPortController.removeListener(_onFormChanged);
    _srtPortController.removeListener(_onFormChanged);
    _hostController.dispose();
    _httpPortController.dispose();
    _srtPortController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  String get _currentHost => _hostController.text.trim();
  String get _currentHttpPort => _httpPortController.text.trim().isNotEmpty ? _httpPortController.text.trim() : '8080';
  String get _currentSrtPort => _srtPortController.text.trim().isNotEmpty ? _srtPortController.text.trim() : '8890';
  bool get _hasHost => _currentHost.isNotEmpty;
  String get _displayHost => _hasHost ? _currentHost : '[MASUKKAN_IP_SERVER]';
  String get _displayScheme => _useHttps ? 'https' : 'http';

  ServerConfig _getConfigFromForm() {
    return ServerConfig(
      host: _currentHost,
      httpPort: int.tryParse(_currentHttpPort) ?? 8080,
      srtPort: int.tryParse(_currentSrtPort) ?? 8890,
      username: _userController.text.trim(),
      password: _passController.text.trim(),
      useHttps: _useHttps,
    );
  }

  Future<void> _testConnection() async {
    if (!_hasHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: MakasnaTheme.amber,
          content: Text('Silakan masukkan alamat IP / Hostname server terlebih dahulu'),
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testSuccess = null;
    });

    final cfg = _getConfigFromForm();
    final res = await context.read<GatewayProvider>().testConnection(cfg);

    setState(() {
      _isTesting = false;
      _testSuccess = res['success'] == true;
      if (res['success'] == true) {
        _testMessage = 'Connected successfully to $_currentHost! Latency: ${res['latency_ms']} ms';
      } else {
        _testMessage = res['message'] ?? 'Connection failed. Check Server IP and Port.';
      }
    });
  }

  Future<void> _connectAndProceed() async {
    if (!_hasHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: MakasnaTheme.red,
          content: Text('Server IP address is required to connect!'),
        ),
      );
      return;
    }

    final cfg = _getConfigFromForm();
    await _prefs.saveRememberSession(_rememberSession);
    await context.read<GatewayProvider>().updateConfig(cfg);

    if (mounted) {
      if (widget.isSwitching) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeNavigationScreen()),
        );
      }
    }
  }

  Widget _buildGuideSection(String title, IconData icon, Color iconColor, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MakasnaTheme.panelElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MakasnaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: MakasnaTheme.border, height: 1),
          const SizedBox(height: 10),
          ...items,
        ],
      ),
    );
  }

  Widget _buildGuideRow(String label, String value, {bool copyable = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: MakasnaTheme.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1019),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _hasHost ? MakasnaTheme.border : MakasnaTheme.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      color: _hasHost ? MakasnaTheme.cyan : MakasnaTheme.amber,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: _hasHost ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      if (!_hasHost) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: MakasnaTheme.amber,
                            content: Text('Please enter your server IP on the "1. SERVER SETUP" tab first.'),
                          ),
                        );
                        return;
                      }
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied to clipboard!'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.copy, size: 14, color: MakasnaTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MAKASNA REMOTE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                ),
                Text(
                  'Broadcast Video Transport',
                  style: TextStyle(fontSize: 10, color: MakasnaTheme.cyan, letterSpacing: 0.3),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MakasnaTheme.cyan,
          labelColor: MakasnaTheme.cyan,
          unselectedLabelColor: MakasnaTheme.textDim,
          tabs: const [
            Tab(icon: Icon(Icons.dns_outlined, size: 18), text: '1. SERVER SETUP'),
            Tab(icon: Icon(Icons.menu_book_outlined, size: 18), text: '2. BROADCAST GUIDE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ========================================================
          // TAB 1: SERVER SETUP
          // ========================================================
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MakasnaTheme.panelElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MakasnaTheme.border),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REMOTE SERVER CONNECTION',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Enter the IP address and Port of your broadcast gateway server to start remote operations.',
                              style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 11.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Form Fields
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MakasnaTheme.panel,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MakasnaTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Field 1: Server IP / Hostname
                      const Text(
                        'SERVER IP / HOSTNAME *',
                        style: TextStyle(color: MakasnaTheme.cyan, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _hostController,
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Enter server IP (e.g. 103.177.96.62)',
                          hintStyle: const TextStyle(color: MakasnaTheme.textDim, fontSize: 12.5),
                          prefixIcon: const Icon(Icons.dns, size: 18, color: MakasnaTheme.cyan),
                          suffixIcon: _hostController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: MakasnaTheme.textDim),
                                  onPressed: () {
                                    _hostController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Field 2 & 3: Ports Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PORT API / HTTP',
                                  style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _httpPortController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: '8080',
                                    prefixIcon: Icon(Icons.api, size: 16, color: MakasnaTheme.textDim),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PORT SRT STREAM',
                                  style: TextStyle(color: MakasnaTheme.blueLight, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _srtPortController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: '8890',
                                    prefixIcon: Icon(Icons.cell_tower, size: 16, color: MakasnaTheme.blueLight),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Field 4 & 5: Credentials
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'USERNAME',
                                  style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _userController,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'admin',
                                    prefixIcon: Icon(Icons.person_outline, size: 16, color: MakasnaTheme.textDim),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PASSWORD',
                                  style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _passController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'password',
                                    prefixIcon: const Icon(Icons.lock_outline, size: 16, color: MakasnaTheme.textDim),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        size: 16,
                                        color: MakasnaTheme.textDim,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // HTTPS Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Use HTTPS (SSL)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('Enable if using SSL secure domain', style: TextStyle(color: MakasnaTheme.textDim, fontSize: 10.5)),
                            ],
                          ),
                          Switch(
                            value: _useHttps,
                            activeColor: MakasnaTheme.cyan,
                            onChanged: (val) => setState(() => _useHttps = val),
                          ),
                        ],
                      ),
                      const Divider(color: MakasnaTheme.border, height: 18),

                      // Remember Session Checkbox (Cache Login)
                      InkWell(
                        onTap: () => setState(() => _rememberSession = !_rememberSession),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberSession,
                                  activeColor: MakasnaTheme.cyan,
                                  checkColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) => setState(() => _rememberSession = val ?? true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Remember Login Session (Auto-Connect)',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Configure once. The app will reconnect automatically on next launch.',
                                      style: TextStyle(color: MakasnaTheme.textDim, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Live Dynamic Endpoints Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _hasHost ? MakasnaTheme.cyan.withOpacity(0.3) : MakasnaTheme.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasHost ? Icons.check_circle_outline : Icons.info_outline,
                            size: 14,
                            color: _hasHost ? MakasnaTheme.cyan : MakasnaTheme.amber,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _hasHost ? 'LIVE ENDPOINT PREVIEW' : 'AWAITING SERVER IP INPUT',
                            style: TextStyle(
                              color: _hasHost ? MakasnaTheme.cyan : MakasnaTheme.amber,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'API Endpoint: $_displayScheme://$_displayHost:$_currentHttpPort',
                        style: TextStyle(
                          color: _hasHost ? Colors.white70 : MakasnaTheme.textDim,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SRT Stream : srt://$_displayHost:$_currentSrtPort',
                        style: TextStyle(
                          color: _hasHost ? MakasnaTheme.blueLight : MakasnaTheme.textDim,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Test Connection Feedback Message
                if (_testMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _testSuccess == true ? MakasnaTheme.greenDim : MakasnaTheme.redDim,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testSuccess == true ? MakasnaTheme.green : MakasnaTheme.red,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testSuccess == true ? Icons.check_circle : Icons.error_outline,
                          size: 16,
                          color: _testSuccess == true ? MakasnaTheme.green : MakasnaTheme.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testMessage!,
                            style: TextStyle(
                              color: _testSuccess == true ? Colors.white : const Color(0xFFFFB3B3),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action Button 1: Test Connection
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MakasnaTheme.cyan,
                    side: const BorderSide(color: MakasnaTheme.cyan),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: MakasnaTheme.cyan),
                        )
                      : const Icon(Icons.network_check, size: 18),
                  label: Text(_isTesting ? 'CONNECTING TO SERVER...' : 'TEST CONNECTION (PING)'),
                ),
                const SizedBox(height: 10),

                // Action Button 2: Connect & Proceed
                ElevatedButton.icon(
                  onPressed: _connectAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MakasnaTheme.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 18, color: Colors.black),
                  label: const Text(
                    'CONNECT & OPEN REMOTE CONTROLLER',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Switch to Tab 2
                Center(
                  child: TextButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.menu_book, size: 15, color: MakasnaTheme.textSecondary),
                    label: const Text(
                      'View Server Instructions & URL Parameters →',
                      style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ========================================================
          // TAB 2: BROADCAST GUIDE (DYNAMIC IP CLIENT)
          // ========================================================
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Banner: Status Server IP yang Aktif
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _hasHost ? const Color(0xFF051B24) : const Color(0xFF241A06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _hasHost ? MakasnaTheme.cyan : MakasnaTheme.amber,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasHost ? Icons.verified : Icons.warning_amber_rounded,
                        color: _hasHost ? MakasnaTheme.cyan : MakasnaTheme.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasHost
                                  ? 'TARGET SERVER: $_currentHost (SRT Port: $_currentSrtPort)'
                                  : 'SERVER IP NOT ENTERED',
                              style: TextStyle(
                                color: _hasHost ? Colors.white : MakasnaTheme.amber,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _hasHost
                                  ? 'All URLs and guidelines below automatically reflect your configured server IP.'
                                  : 'Enter your server IP in Tab "1. SERVER SETUP" to generate endpoint URLs automatically.',
                              style: const TextStyle(color: MakasnaTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Section 1: Ingest
                _buildGuideSection(
                  '1. INGEST VIDEO (CAMERA / ENCODER TO SERVER)',
                  Icons.upload,
                  MakasnaTheme.cyan,
                  [
                    const Text(
                      'Camera or upstream encoder (OBS / vMix) sends broadcast signal to server via SRT Caller:',
                      style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    _buildGuideRow(
                      'OBS Studio Ingest URL Format (Service: Custom):',
                      'srt://$_displayHost:$_currentSrtPort?streamid=publish:STREAM_NAME&latency=2000000',
                    ),
                    _buildGuideRow(
                      'vMix Encoder Parameters (Add Input > Stream/SRT > Type: Caller):',
                      'Hostname: $_displayHost | Port: $_currentSrtPort | StreamID: publish:STREAM_NAME',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Recommended Field Encoder Checklist:\n'
                      '• Codec: H.264 or H.265 (HEVC 8-bit Main Profile)\n'
                      '• Keyframe GOP: 1s or 2s (Strict Closed GOP, Do not use Auto)\n'
                      '• B-Frames: 0 (Zero Latency Mode)\n'
                      '• Rate Control: CBR (Constant Bitrate)',
                      style: TextStyle(color: MakasnaTheme.textDim, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),

                // Section 2: Receiver
                _buildGuideSection(
                  '2. RECEIVE VIDEO (STUDIO VMIX / VLC / PLAYOUT)',
                  Icons.download,
                  MakasnaTheme.blueLight,
                  [
                    const Text(
                      'Studio playout or monitoring client pulls (Caller/Listener) broadcast feed from server:',
                      style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    _buildGuideRow(
                      'vMix Listener Format (Type: Caller):',
                      'Hostname: $_displayHost | Port: $_currentSrtPort | StreamID: read:STREAM_NAME',
                    ),
                    _buildGuideRow(
                      'VLC Media Player Format (Media > Open Network Stream):',
                      'srt://$_displayHost:$_currentSrtPort?streamid=read:STREAM_NAME',
                    ),
                    _buildGuideRow(
                      'Web Dashboard URL Format:',
                      '$_displayScheme://$_displayHost:$_currentHttpPort',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Note: In vMix, enter "read:STREAM_NAME" in the Stream ID field without typing "streamid=" prefix.',
                      style: TextStyle(color: MakasnaTheme.amber, fontSize: 11),
                    ),
                  ],
                ),

                // Section 3: Master Recorder
                _buildGuideSection(
                  '3. MASTER ISO RECORDING & GOOGLE DRIVE SYNC',
                  Icons.fiber_manual_record,
                  MakasnaTheme.red,
                  [
                    const Text(
                      '• Open RECORDER tab in the bottom navigation bar.\n'
                      '• Select Camera / Inbound feed in FEED SOURCE dropdown.\n'
                      '• Choose recording format: MP4 Universal or MOV QuickTime.\n'
                      '• Press the red RECORD button to start master recording.\n'
                      '• Recording operations run independently without interrupting live streams.\n'
                      '• Finished ISO video segments automatically upload to Google Drive.',
                      style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),

                // Section 4: Deteksi Audio Pecah
                _buildGuideSection(
                  '4. AUDIO MONITORING & DIGITAL CLIPPING DETECTION',
                  Icons.volume_up,
                  MakasnaTheme.green,
                  [
                    const Text(
                      '• Monitor the True Peak VU Meter bar in SIGNAL or RECORDER tabs.\n'
                      '• If meter reaches the red zone and DIGITAL CLIP! indicator lights up, the audio signal from field mixer is overloaded (0 dBFS).\n'
                      '• Immediately instruct field audio engineers to trim mixer gain.',
                      style: TextStyle(color: MakasnaTheme.textSecondary, fontSize: 12, height: 1.5),
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
}
