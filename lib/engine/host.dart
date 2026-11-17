import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';

/// Petit stockage clé → valeur, gardé sur ce poste seulement.
abstract interface class LocalVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Stockage sécurisé de Windows (Credential Manager), comme la session.
class SecureVault implements LocalVault {
  SecureVault([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stockage en mémoire, pour les tests et la démonstration.
class MemoryVault implements LocalVault {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Clés des fournisseurs IA (D-022) : saisies dans les réglages, gardées dans
/// le stockage sécurisé de ce poste et envoyées seulement au fournisseur,
/// jamais au serveur LeadDesk.
class ProviderKeys {
  ProviderKeys(this.vault);

  final LocalVault vault;

  /// Une clé par type de fournisseur (`anthropic`, `openai`…).
  static String _slot(String driver) => 'leaddesk.provider.$driver';

  Future<String?> forDriver(String driver) async {
    final key = (await vault.read(_slot(driver)))?.trim();
    return key == null || key.isEmpty ? null : key;
  }

  /// Enregistre la clé ; une clé vide l'efface.
  Future<void> setForDriver(String driver, String key) {
    final cleaned = key.trim();
    return cleaned.isEmpty
        ? vault.delete(_slot(driver))
        : vault.write(_slot(driver), cleaned);
  }

  Future<String?> anthropic() => forDriver('anthropic');

  Future<void> setAnthropic(String key) => setForDriver('anthropic', key);

  /// Fin de la clé, pour l'afficher sans la révéler (`…a1b2`).
  static String mask(String key) =>
      key.length <= 4 ? '…' : '…${key.substring(key.length - 4)}';
}

/// Cet ordinateur, hôte des exécutions (D-022) : enregistré une fois sous un
/// `installation_id` gardé localement, puis signe de vie régulier.
class HostDevice {
  HostDevice({
    required this.api,
    required this.vault,
    this.heartbeatEvery = const Duration(minutes: 1),
    String? name,
    String? platform,
  }) : name = name ?? _hostName(),
       platform = platform ?? _platform();

  final ApiClient api;
  final LocalVault vault;
  final Duration heartbeatEvery;
  final String name;
  final String platform;

  static const String _installationKey = 'leaddesk.installation_id';

  int? _id;
  Timer? _timer;

  /// Identifiant serveur du poste, une fois enregistré.
  int? get id => _id;

  /// Enregistre le poste (sans doublon) et lance le signe de vie.
  Future<int> register() async {
    var installation = await vault.read(_installationKey);
    if (installation == null || installation.isEmpty) {
      installation = uuidV4();
      await vault.write(_installationKey, installation);
    }
    final data =
        (await api.post('devices', <String, Object?>{
              'installation_id': installation,
              'name': name,
              'platform': platform,
            }))!
            as Map<String, Object?>;
    final id = (data['id']! as num).toInt();
    _id = id;
    _timer?.cancel();
    _timer = Timer.periodic(heartbeatEvery, (_) => heartbeat());
    return id;
  }

  /// Un signe de vie ; une erreur passagère est ignorée (le suivant suffira).
  Future<void> heartbeat() async {
    final id = _id;
    if (id == null) {
      return;
    }
    try {
      await api.post('devices/$id/heartbeat');
    } on Object {
      // Réseau coupé : le poste paraîtra hors ligne jusqu'au prochain signe.
    }
  }

  void dispose() => _timer?.cancel();

  static String _hostName() {
    try {
      final host = Platform.localHostname.trim();
      return host.isEmpty ? 'Cet ordinateur' : host;
    } on Object {
      return 'Cet ordinateur';
    }
  }

  static String _platform() {
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    return 'windows';
  }

  /// UUID version 4, tiré au hasard cryptographique.
  static String uuidV4([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
