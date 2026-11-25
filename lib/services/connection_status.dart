import 'package:flutter/foundation.dart';

/// Status koneksi ke database sensor.
///
/// Diisi otomatis sama [FirebaseSensorService] berdasarkan event/error
/// dari Firebase Realtime Database, bukan toggle manual.
class ConnectionStatus {
  static final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);

  /// Alasan terakhir koneksi dianggap putus (null = aman).
  static final ValueNotifier<String?> statusMessage = ValueNotifier<String?>(
    null,
  );

  static void connected() {
    isConnected.value = true;
    statusMessage.value = null;
  }

  static void disconnected(String message) {
    isConnected.value = false;
    statusMessage.value = message;
  }
}
