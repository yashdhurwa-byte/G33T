import 'dart:async';
import 'package:mornye/services/link/client/link_client_discovery.dart';

/// Bonsoir discovery stubbed out for offline lean architecture.
class BonsoirLinkServiceBrowser implements LinkServiceBrowser {
  @override
  Future<Stream<LinkServiceEvent>> start() async {
    return const Stream.empty();
  }

  @override
  Future<void> stop() async {}
}
