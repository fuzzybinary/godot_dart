/// Portions of this are taken from the hotreloader package:
/// https://github.com/vegardit/dart-hotreloader/
///
/// Copyright  Sebastian Thomschke, Vegard IT GmbH
/// Licensed under Apache 2.0
///
import 'dart:developer';

import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart';

enum HotReloadResult {
  /// Hot-reloading was not performed because of a veto by the onBeforeReload listener.
  skipped,

  /// Hot-reloading of all isolate failed.
  failed,

  /// Hot-reloading of some isolates failed.
  partiallySucceeded,

  /// Hot-reloading of all isolates succeeded.
  succeeded
}

Future<vms.VmService> createVmService() async {
  final devServiceURL = (await Service.getInfo()).serverUri;
  if (devServiceURL == null) {
    throw StateError(
        'VM service not available! You need to run dart with --enable-vm-service.');
  }
  final wsURL = convertToWebSocketUrl(serviceProtocolUrl: devServiceURL);
  return vmServiceConnectUri(wsURL.toString());
}

class HotReloader {
  late final vms.VmService _vmService;

  static Future<HotReloader?> create() async {
    return HotReloader._(await createVmService());
  }

  HotReloader._(this._vmService);

  Future<HotReloadResult> reloadCode() async {
    final reloadReports = <vms.IsolateRef, vms.ReloadReport>{};
    final failedReloadReports = <vms.IsolateRef, vms.ReloadReport>{};
    final stopwatch = Stopwatch();
    stopwatch.start();
    for (final isolateRef
        in (await _vmService.getVM()).isolates ?? <vms.IsolateRef>[]) {
      if (isolateRef.id == null) {
        //log.fine(
        //    'Cannot hot-reload code of isolate [${isolateRef.name}] since its ID is null.');
        continue;
      }
      //log.fine('Hot-reloading code of isolate [${isolateRef.name}]...');

      try {
        final reloadReport = await _vmService.reloadSources(
          isolateRef.id!,
          force: false,
        );
        if (!(reloadReport.success ?? false)) {
          failedReloadReports[isolateRef] = reloadReport;
        }
        reloadReports[isolateRef] = reloadReport;
        //log.finest('reloadReport for [${isolateRef.name}]: $reloadReport');
      } on vms.SentinelException catch (ex) {
        // happens when the isolate has been garbage collected in the meantime
        // log.warning(
        //     'Failed to reload code of isolate [${isolateRef.name}]: $ex');
      }
    }
    stopwatch.stop();
    print(
        '[godot_dart] Hot reload complete in ${stopwatch.elapsedMilliseconds}ms');

    if (reloadReports.isEmpty) {
      return HotReloadResult.skipped;
    }

    if (failedReloadReports.isEmpty) {
      //log.info('Hot-reloading code succeeded.');
      return HotReloadResult.succeeded;
    }

    if (failedReloadReports.length == reloadReports.length) {
      //{type:ReloadReport,success:false,notices:[{type:ReasonForCancelling,message:"lib/src/config.dart:32:1: Error: Expected ';' after this."}]}
      // log.severe(
      //     'Hot-reloading code failed:\n ${failedReloadReports.values.first.json?['notices'][0]['message']}');
      return HotReloadResult.failed;
    }

    // log.severe(
    //     'Hot-reloading code failed for some isolates [$failedIsolates]:\n ${failedReloadReports.values.first.json?['notices'][0]['message']}');
    return HotReloadResult.partiallySucceeded;
  }

  Future<void> stop() async {
    // to prevent "Unhandled exception: reloadSources: (-32000) Service connection disposed"
    await Future<void>.delayed(const Duration(seconds: 2));

    await _vmService.dispose();
  }
}
