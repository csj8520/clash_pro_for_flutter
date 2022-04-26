import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/io.dart';

import 'package:clash_for_flutter/types/connect.dart';
import 'package:clash_for_flutter/types/clash_core.dart';
import 'package:clash_for_flutter/utils/system_proxy.dart';

final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9090'));

class StoreClashCore extends GetxController {
  var version = ClashCoreVersion(premium: true, version: '').obs;
  var address = ''.obs;
  var secret = ''.obs;
  var config = ClashCoreConfig(
    port: 0,
    socksPort: 0,
    redirPort: 0,
    tproxyPort: 0,
    mixedPort: 0,
    authentication: [],
    allowLan: false,
    bindAddress: '',
    mode: '',
    logLevel: '',
    ipv6: false,
  ).obs;

  IOWebSocketChannel? connectChannel;
  var connect = Connect(downloadTotal: 0, uploadTotal: 0, connections: []).obs;
  Map<String, List<int>> _preConnectsNet = {};

  SystemProxyConfig get proxyConfig {
    final mixedPort = config.value.mixedPort == 0 ? null : config.value.mixedPort;
    final httpPort = mixedPort ?? config.value.port;
    final httpsPort = mixedPort ?? config.value.port;
    final socksPort = mixedPort ?? config.value.socksPort;
    return SystemProxyConfig(
      http: httpPort == 0 ? null : '127.0.0.1:$httpPort',
      https: httpsPort == 0 ? null : '127.0.0.1:$httpsPort',
      socks: socksPort == 0 ? null : '127.0.0.1:$socksPort',
    );
  }

  void initConnect() async {
    connectChannel = IOWebSocketChannel.connect(Uri.parse('ws://${address.value}/connections?token=${secret.value}'));
    connectChannel!.stream.listen(_handleConnectStream);
  }

  _handleConnectStream(dynamic event) {
    connect.value = Connect.fromJson(json.decode(event));
    final preConnects = _preConnectsNet;
    _preConnectsNet = {};
    for (var it in connect.value.connections) {
      final pre = preConnects[it.id];
      _preConnectsNet[it.id] = [it.download, it.upload];
      if (pre == null) continue;
      it.speed.download = it.download - pre[0];
      it.speed.upload = it.upload - pre[1];
    }
    connect.refresh();
  }

  Future<void> waitCoreStart() async {
    while (true) {
      final hello = await fetchHello();
      if (hello) return;
    }
  }

  setApi(String _address, String _secret) {
    address.value = _address;
    secret.value = _secret;
    dio.options.baseUrl = 'http://$_address';
    if (_secret.isNotEmpty) dio.options.headers['Authorization'] = 'Bearer $_secret';
  }

  Future<bool> fetchHello() async {
    try {
      final res = await dio.get('/');
      return res.data['hello'] == 'clash';
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchVersion() async {
    final res = await dio.get('/version');
    version.value = ClashCoreVersion.fromJson(res.data);
  }

  Future<void> fetchConfig() async {
    final res = await dio.get('/configs');
    config.value = ClashCoreConfig.fromJson(res.data);
  }

  Future<void> fetchConfigUpdate(Map<String, dynamic> config) async {
    await dio.patch('/configs', data: config);
    await fetchConfig();
  }

  Future<void> fetchCloseConnection(String id) async {
    await dio.delete('/connections/${Uri.encodeComponent(id)}');
  }
}
