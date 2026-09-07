import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/campus_cookie_bridge.dart';
import '../../../core/providers/api_client_provider.dart';
import 'identity_auth_web_surface.dart';

Future<bool> showCampusAuthorization(
  BuildContext context,
  DateTime date,
) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CampusAuthorizationScreen(date: date),
        fullscreenDialog: true,
      ),
    ) ??
    false;

class CampusAuthorizationScreen extends ConsumerStatefulWidget {
  const CampusAuthorizationScreen({super.key, required this.date});
  final DateTime date;
  @override
  ConsumerState<CampusAuthorizationScreen> createState() =>
      _CampusAuthorizationScreenState();
}

class _CampusAuthorizationScreenState
    extends ConsumerState<CampusAuthorizationScreen> {
  late final IdentityAuthWebSurfaceController _surface;
  final _visited = <Uri>{Uri.https('webvpn.tsinghua.edu.cn', '/')};
  bool _ready = false;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _surface = createIdentityAuthWebSurfaceController(
      IdentityAuthWebCallbacks(
        onPageStarted: (_) {},
        onJavaScriptMessage: (_) {},
        onNavigationRequest: (url) {
          final uri = Uri.tryParse(url);
          return uri == null ||
              uri.scheme != 'https' ||
              !{
                ...CampusCookieBridge.hosts,
                'id.tsinghua.edu.cn',
              }.contains(uri.host);
        },
        onPageFinished: (url) async {
          final uri = Uri.tryParse(url);
          if (uri != null &&
              uri.scheme == 'https' &&
              CampusCookieBridge.hosts.contains(uri.host)) {
            _visited.add(uri);
          }
        },
      ),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (!{
        TargetPlatform.android,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform)) {
        setState(() => _error = '当前平台尚未支持校园访问授权');
        return;
      }
      final availability = await _surface.initialize();
      if (!mounted) return;
      if (!availability.isAvailable) {
        setState(() => _error = availability.message ?? '无法打开校园认证');
        return;
      }
      setState(() => _ready = true);
      await _surface.loadUrl('https://webvpn.tsinghua.edu.cn/');
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开校园认证，请重试');
    }
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final headers = <Uri, String>{};
      for (final uri in _visited.toList()) {
        final header = await _surface.getCookieHeaderForUrl(uri.toString());
        if (header != null && header.isNotEmpty) headers[uri] = header;
      }
      if (!mounted) return;
      final api = ref.read(apiClientProvider);
      await CampusCookieBridge(api.cookieJar).importHeaders(headers);
      final day = widget.date.toIso8601String().split('T').first;
      await api.getCalendar(day, day).timeout(const Duration(seconds: 30));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = '尚未连接教务系统，请完成校园认证后重试');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    unawaited(_surface.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('校园访问授权'),
      actions: [
        IconButton(
          tooltip: '重新加载',
          onPressed: _ready
              ? () => _surface.loadUrl('https://webvpn.tsinghua.edu.cn/')
              : _initialize,
          icon: const Icon(Icons.refresh),
        ),
        TextButton(
          onPressed: _ready && !_verifying ? _verify : null,
          child: Text(_verifying ? '正在验证' : '验证并返回'),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_verifying) const LinearProgressIndicator(),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        Expanded(
          child: _ready
              ? _surface.buildView()
              : _error == null
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.expand(),
        ),
      ],
    ),
  );
}
