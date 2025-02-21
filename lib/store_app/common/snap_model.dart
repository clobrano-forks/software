import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:safe_change_notifier/safe_change_notifier.dart';
import 'package:snapd/snapd.dart';
import 'package:software/services/app_change_service.dart';
import 'package:software/services/color_generator.dart';
import 'package:software/snapx.dart';
import 'package:xdg_icons/xdg_icons.dart';
import 'package:yaru_icons/yaru_icons.dart';

class SnapModel extends SafeChangeNotifier {
  final AppChangeService _appChangeService;
  final SnapdClient _client;
  final ColorGenerator? colorGenerator;
  final String huskSnapName;
  Snap? _storeSnap;
  Snap? _localSnap;
  bool online;

  SnapModel(
    this._client,
    this._appChangeService, {
    this.colorGenerator,
    required this.huskSnapName,
    this.online = true,
  })  : _appChangeInProgress = false,
        _channelToBeInstalled = '',
        selectableChannels = {},
        connections = {};

  StreamSubscription<bool>? _snapChangesSub;

  /// Apps this snap provides.
  List<SnapApp>? get apps => _localSnap?.apps;

  /// The base snap this snap uses.
  String? get base => _storeSnap?.base ?? _localSnap?.base;

  /// The channel this snap is from, e.g. "stable".
  String? get channel => _storeSnap?.channel ?? _localSnap?.channel;

  Map<String, SnapChannel> selectableChannels;

  /// Common IDs this snap contains.
  List<String>? get commonIds => _storeSnap?.commonIds ?? _localSnap?.commonIds;

  /// The confinement this snap is using.
  SnapConfinement? get confinement =>
      _storeSnap?.confinement ?? _localSnap?.confinement;

  /// Contact URL.
  String? get contact => _storeSnap?.contact ?? _localSnap?.contact;

  /// Multi line description.
  String? get description => _storeSnap?.description ?? _localSnap?.description;

  /// Download size in bytes.
  int? get downloadSize => _storeSnap?.downloadSize ?? _localSnap?.downloadSize;

  String? get iconUrl => _storeSnap?.iconUrl ?? _localSnap?.iconUrl;

  /// Unique ID for this snap.
  String? get id => _storeSnap?.id ?? _localSnap?.id;

  /// The date this snap was installed.
  String get installDate {
    if (_localSnap == null || _localSnap!.installDate == null) return '';

    return DateFormat.yMMMEd().format(_localSnap!.installDate!);
  }

  /// Installed size in bytes.
  int? get installedSize => _localSnap?.installedSize;

  /// Package license.
  String? get license => _storeSnap?.license ?? _localSnap?.license;

  /// The date this snap was installed.
  String get releasedAt {
    if (selectableChannels[channelToBeInstalled] == null) return '';

    return DateFormat.yMMMEd()
        .format(selectableChannels[channelToBeInstalled]!.releasedAt);
  }

  /// Media associated with this snap.
  List<SnapMedia>? get media => _storeSnap?.media ?? _localSnap?.media;

  /// Unique name for this snap. Use [title] for displaying.
  String? get name => _storeSnap?.name ?? _localSnap?.name;

  /// Publisher information.
  SnapPublisher? get publisher =>
      _storeSnap?.publisher ?? _localSnap?.publisher;

  /// Revision of this snap.
  String? get revision => _storeSnap?.revision ?? _localSnap?.revision;

  /// URL linking to the snap store page on this snap.
  String? get storeUrl => _storeSnap?.storeUrl ?? _localSnap?.storeUrl;

  /// Single line summary.
  String? get summary => _storeSnap?.summary ?? _localSnap?.summary;

  /// Title of this snap.
  String? get title => _storeSnap?.title ?? _localSnap?.title;

  /// The channel that updates will be installed from, e.g. "stable".
  String? get trackingChannel => _localSnap?.trackingChannel;

  /// Tracks this snap uses.
  List<String>? get tracks => _storeSnap?.tracks;

  /// Type of snap.
  String? get type => _storeSnap?.type ?? _localSnap?.type;

  /// Version of this snap.
  String? get version => _localSnap?.version ?? _storeSnap?.version;

  /// Website URL.
  String? get website => _storeSnap?.website ?? _localSnap?.website;

  num? get installPercent => downloadSize == null || installedSize == null
      ? 0
      : installedSize! / downloadSize!;

  bool _appChangeInProgress;
  bool get appChangeInProgress => _appChangeInProgress;
  set appChangeInProgress(bool value) {
    if (value == _appChangeInProgress) return;
    _appChangeInProgress = value;
    notifyListeners();
  }

  bool get snapIsInstalled =>
      _localSnap != null && _localSnap!.installDate != null;

  String _channelToBeInstalled;
  String get channelToBeInstalled => _channelToBeInstalled;
  set channelToBeInstalled(String value) {
    if (value == _channelToBeInstalled) return;
    _channelToBeInstalled = value;
    notifyListeners();
  }

  Future<void> init() async {
    _localSnap = await _findLocalSnap(huskSnapName);
    if (online) {
      _storeSnap = await _findSnapByName(huskSnapName).timeout(
        const Duration(milliseconds: 2500),
        onTimeout: () {
          notifyListeners();
          return null;
        },
      );
    }
    if (_storeSnap != null && _storeSnap!.tracks.isNotEmpty) {
      for (var track in _storeSnap!.tracks) {
        for (var risk in ['stable', 'candidate', 'beta', 'edge']) {
          var name = '$track/$risk';
          var channel = _storeSnap!.channels[name];
          final channelName = '$track/$risk';
          if (channel != null) {
            selectableChannels.putIfAbsent(channelName, () => channel);
          }
        }
      }
    }
    if (snapIsInstalled && selectableChannels.entries.isNotEmpty) {
      if (trackingChannel != null &&
          selectableChannels.entries
              .where((element) => element.key == trackingChannel)
              .isNotEmpty) {
        channelToBeInstalled = trackingChannel!;
      } else {
        channelToBeInstalled = selectableChannels.entries.first.key;
      }
    } else if (_storeSnap != null) {
      channelToBeInstalled = selectableChannels.entries.first.key;
    }

    _snapChangesSub = _appChangeService.snapChangesInserted.listen((_) {
      if (_storeSnap != null && _localSnap == null) {
        appChangeInProgress = _appChangeService.getChange(_storeSnap!) != null;
      }
      if (_localSnap != null) {
        appChangeInProgress = _appChangeService.getChange(_localSnap!) != null;
      }
      notifyListeners();
    });

    await loadConnections();
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _snapChangesSub?.cancel();
    super.dispose();
  }

  Future<Snap?> _findLocalSnap(String huskSnapName) async {
    await _client.loadAuthorization();
    try {
      return await _client.getSnap(huskSnapName);
    } on SnapdException {
      return null;
    }
  }

  Future<Snap?> _findSnapByName(String name) async {
    await _client.loadAuthorization();
    try {
      final snaps = (await _client.find(name: name));
      return snaps.first;
    } on SnapdException {
      return null;
    }
  }

  Future<void> installSnap() async {
    if (name == null) return;
    await _client.loadAuthorization();
    final changeId = await _client.install(
      name!,
      channel: channelToBeInstalled,
      classic: confinement == SnapConfinement.classic,
    );
    await _appChangeService.addChange(
      _storeSnap!,
      changeId,
    );
    _localSnap = await _findLocalSnap(huskSnapName);
    notifyListeners();
  }

  Future<void> removeSnap() async {
    if (name == null) return;
    await _client.loadAuthorization();
    final changeId = await _client.remove(name!);
    await _appChangeService.addChange(_localSnap!, changeId);
    _localSnap = await _findLocalSnap(huskSnapName);
    notifyListeners();
  }

  Future<void> refreshSnapApp() async {
    if (name == null || channelToBeInstalled.isEmpty) return;
    await _client.loadAuthorization();
    final changeId =
        await _client.refresh(name!, channel: channelToBeInstalled);
    await _appChangeService.addChange(_localSnap!, changeId);
    notifyListeners();
  }

  Future<void> connect({
    required String snap,
    required String plug,
    required String slotSnap,
    required String slot,
  }) async {
    await _client.loadAuthorization();
    await _client.connect(snap, plug, slotSnap, slot);
    notifyListeners();
  }

  Future<void> disconnect({
    required String snap,
    required String plug,
    required String slotSnap,
    required String slot,
  }) async {
    await _client.loadAuthorization();
    await _client.disconnect(snap, plug, slotSnap, slot);
    notifyListeners();
  }

  Map<String, Set<String>> connections;
  Future<void> loadConnections() async {
    await _client.loadAuthorization();
    final response = await _client.getConnections();

    for (final connection in response.established) {
      final interface = connection.interface;
      final plug = '${connection.plug.snap}:${connection.plug.plug}';
      final slot =
          '${connection.slot.snap != 'core' ? connection.slot.snap : ''}:${connection.slot.slot}';

      if (connection.plug.snap.contains(huskSnapName) &&
          interface != 'content') {
        connections.putIfAbsent(
          interface,
          () => {plug, slot},
        );
      }
    }
  }

  String? get versionString => selectableChannels[channelToBeInstalled] != null
      ? selectableChannels[channelToBeInstalled]!.version
      : version;

  Color get surfaceTintColor {
    if (_surfaceTintColor == null && colorGenerator != null) {
      _generateSurfaceTintColor();
    }
    return _surfaceTintColor ?? Colors.transparent;
  }

  Color? _surfaceTintColor;

  Future<void> _generateSurfaceTintColor() async {
    final url = _storeSnap?.iconUrl;
    final color = url != null ? await colorGenerator?.generateColor(url) : null;
    if (_surfaceTintColor != color) {
      _surfaceTintColor = color;
      notifyListeners();
    }
  }

  void open() {
    if (_localSnap == null && _localSnap!.apps.isEmpty) return;
    Process.start(
      _localSnap!.apps.first.name,
      [],
      mode: ProcessStartMode.detached,
    );
  }

  String? get _desktopFile =>
      apps != null && apps!.isNotEmpty && apps!.first.desktopFile != null
          ? apps!.first.desktopFile!
          : null;

  Widget offlineIcon = fallbackSnapIcon;
  String _iconLine = '';

  void loadOfflineIcon() {
    if (_desktopFile != null) {
      File? file = File(_desktopFile!);
      (file
              .openRead()
              .map(utf8.decode)
              .transform(const LineSplitter())
              .where((line) => line.contains('Icon='))
              .first)
          .then((line) {
        _iconLine = line.replaceAll('Icon=', '');
        if (_iconLine.endsWith('.png') ||
            _iconLine.endsWith('.jpg') ||
            _iconLine.endsWith('.jpeg')) {
          offlineIcon = Image.file(
            File(_iconLine),
            filterQuality: FilterQuality.medium,
            width: 50,
          );
        }
        if (_iconLine.endsWith('.svg')) {
          try {
            offlineIcon = SvgPicture.file(
              File(_iconLine),
              width: 50,
            );
          } finally {
            if (offlineIcon != fallbackSnapIcon) {
              offlineIcon = fallbackSnapIcon;
            }
          }
        }
        if (!_iconLine.contains('/')) {
          offlineIcon = XdgIconTheme(
            data: const XdgIconThemeData(theme: 'Yaru'),
            child: XdgIcon(name: _iconLine, size: 48),
          );
        }
        notifyListeners();
        return;
      });
    }
    notifyListeners();
  }
}

const fallbackSnapIcon = Icon(
  YaruIcons.package_snap,
  size: 50,
);
