import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { isConnected, isDisconnected, isConnecting }

final connectivityStatusProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
        (ref) => ConnectivityNotifier());

class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  final Connectivity _connectivity = Connectivity();

  ConnectivityNotifier() : super(ConnectivityStatus.isConnecting) {
    // connectivity_plus v6+ returns List<ConnectivityResult>
    _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
    _initialCheck();
  }

  Future<void> _initialCheck() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (results.isEmpty ||
        (results.length == 1 && results.first == ConnectivityResult.none)) {
      state = ConnectivityStatus.isDisconnected;
    } else {
      state = ConnectivityStatus.isConnected;
    }
  }
}
