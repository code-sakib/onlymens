

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppMethodChannels extends StatefulWidget {
  const AppMethodChannels({super.key});

   static const MethodChannel _channel =
      MethodChannel('com.sakib.onlymens/channel');

  @override
  State<AppMethodChannels> createState() => _AppMethodChannelsState();
}

class _AppMethodChannelsState extends State<AppMethodChannels> {
  String _status = 'idle';

  // State to hold the list of selected apps
  List<String> _selectedApps = [];

  @override
  void initState() {
    super.initState();
    AppMethodChannels._channel.setMethodCallHandler(_handleMethod);
  }

  // Handle method calls from the native (iOS) side
  Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onAppSelectionUpdated':
        final List<dynamic>? bundleIds = call.arguments as List<dynamic>?;
        if (bundleIds != null) {
          setState(() {
            _selectedApps = bundleIds.cast<String>();
            _status = 'Selected apps: ${_selectedApps.join(", ")}';
          });
        }
        break;
      default:
        debugPrint('Unknown method called: ${call.method}');
    }
  }

  Future<void> _requestAuth() async {
    setState(() => _status = 'Requesting authorization...');
    try {
      final bool? result = await AppMethodChannels._channel.invokeMethod('requestAuthorization');
      setState(() => _status = result == true ? 'Authorized ✅' : 'Denied ❌');
    } on PlatformException catch (e) {
      setState(() => _status = 'Error: ${e.message}');
    }
  }

  Future<void> _listApps() async {
    setState(() => _status = 'Displaying app picker...');
    try {
      final bool? result = await AppMethodChannels._channel.invokeMethod('listapps');
      if (result == false) {
        setState(() => _status = 'Failed to display app picker ❌');
      }
    } on PlatformException catch (e) {
      setState(() => _status = 'Error: ${e.message}');
    }
  }

  Future<void> _unblockAll() async {
    setState(() => _status = 'Unblocking all...');
    try {
      final bool? result = await AppMethodChannels._channel.invokeMethod('unblockApps');
      setState(() {
        _selectedApps = []; // Clear the list of selected apps in Flutter state
        _status = result == true ? 'All apps unblocked ✅' : 'Unblock failed ❌';
      });
    } on PlatformException catch (e) {
      setState(() => _status = 'Error: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ScreenTime Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _requestAuth,
              child: const Text('Request Screen Time Authorization'),
            ),
            ElevatedButton(
              onPressed: _listApps,
              child: const Text('List Apps'),
            ),
            ElevatedButton(
              onPressed: _unblockAll,
              child: const Text('Unblock All'),
            ),
            const SizedBox(height: 20),
            Text(
              'Status: $_status',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            if (_selectedApps.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Apps:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedApps.length,
                        itemBuilder: (context, index) {
                          return Text(_selectedApps[index]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}