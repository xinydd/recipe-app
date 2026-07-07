import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class NetworkAwareWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReconnected;

  const NetworkAwareWidget({
    super.key,
    required this.child,
    this.onReconnected,
  });

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
    if (mounted && _isConnected != isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
      if (isConnected && widget.onReconnected != null) {
        widget.onReconnected!();
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isConnected)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.red[700],
              padding: const EdgeInsets.all(8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'No Internet Connection',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}