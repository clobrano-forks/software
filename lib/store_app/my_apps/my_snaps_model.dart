import 'dart:async';
import 'dart:io';

import 'package:safe_change_notifier/safe_change_notifier.dart';
import 'package:snapd/snapd.dart';
import 'package:software/services/app_change_service.dart';

class MySnapsModel extends SafeChangeNotifier {
  final SnapdClient _client;
  final AppChangeService _appChangeService;
  StreamSubscription<bool>? _snapChangesSub;
  List<Snap> _localSnaps;
  List<Snap> get localSnaps => _localSnaps;

  MySnapsModel(
    this._client,
    this._appChangeService,
  ) : _localSnaps = [];

  Future<void> init() async {
    await _loadLocalSnaps();
    _snapChangesSub = _appChangeService.snapChangesInserted.listen((_) async {
      await _loadLocalSnaps();
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _snapChangesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadLocalSnaps() async {
    await _client.loadAuthorization();
    try {
      _localSnaps = (await _client.getSnaps())
          .where(
            (snap) => _appChangeService.getChange(snap) == null,
          )
          .toList();
    } on SocketException {
      return;
    }
    _localSnaps.sort((a, b) => a.name.compareTo(b.name));
  }
}
