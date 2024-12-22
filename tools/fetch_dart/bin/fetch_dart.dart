import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:args/args.dart';
import 'package:github/github.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final destDir = Directory('src/dart_dll');
final destBinDir = Directory(path.join(destDir.path, 'bin/release'));
final destIncludeDir = Directory(path.join(destDir.path, 'include'));

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addOption(
      'local',
      abbr: 'l',
      help:
          'Use a local copy of dart_shared_library to fetch an updated dyanmic library.',
    )
    ..addOption(
      'version',
      help:
          'Specify the version of dart_shared_library to fetch. Defaults to the most recent.',
    );
}

void printUsage(ArgParser argParser) {
  print('Usage: dart fetch_dart.dart <flags> [arguments]');
  print(argParser.usage);
}

void main(List<String> arguments) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((e) {
    print(e.message);
  });

  final ArgParser argParser = buildParser();
  final ArgResults results;
  try {
    results = argParser.parse(arguments);
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
    return;
  }

  // Process the parsed arguments.
  if (results.wasParsed('help')) {
    printUsage(argParser);
    return;
  }
  if (results.wasParsed('verbose')) {
    Logger.root.level = Level.ALL;
  }

  if (!(await destDir.exists())) {
    Logger.root.shout(
        '❌ Could not find ${destDir.path}. Make sure you are running from the root of the repo.');
    return;
  }

  // Create the two destination directories, in case they don't exist
  if (!destBinDir.existsSync()) destBinDir.create(recursive: true);
  if (!destIncludeDir.existsSync()) destIncludeDir.create(recursive: true);

  if (results.wasParsed('local')) {
    _fetchLocal(results['local'] as String, Logger.root);
  } else {
    _fetchFromGithub(results['version'] as String?, Logger.root);
  }
}

void _fetchLocal(String localPath, Logger l) async {
  l.info('Fetching local artifacts from $localPath');
  final localDir = Directory(localPath);
  if (!(await localDir.exists())) {
    l.severe('❌ Could not find directory $localPath.');
    return;
  }

  String platformLocation;
  List<String> platformFiles;
  if (Platform.isWindows) {
    platformLocation = path.join(localPath, 'build/src/Release');
    platformFiles = ['dart_dll.dll', 'dart_dll.lib'];
  } else if (Platform.isLinux) {
    platformLocation = path.join(localPath, 'build/src');
    platformFiles = ['libdart_dll.so'];
  } else if (Platform.isMacOS) {
    platformLocation = path.join(localPath, 'build/src');
    platformFiles = ['libdart_dll.dylib'];
  } else {
    l.shout('Running on unknown platform!');
    return;
  }

  for (final copyFile in platformFiles) {
    final srcFile = File(path.join(localPath, platformLocation, copyFile));
    final destPath = path.join(destBinDir.path, copyFile);
    l.info('  ${srcFile.path} => $destPath');
    await srcFile.copy(destPath);
  }

  l.info('Copying header files from $localPath');
  final dartHeaderDir = 'dart-sdk/sdk/runtime/include';
  final dartHeaderList = ['dart_api.h', 'dart_tools_api.h'];
  for (final copyFile in dartHeaderList) {
    final srcFile = File(path.join(localPath, dartHeaderDir, copyFile));
    final destPath = path.join(destIncludeDir.path, copyFile);
    l.info('  ${srcFile.path} => $destPath');
    await srcFile.copy(destPath);
  }

  // Copy dart_dll header
  final srcFile = File(path.join(localPath, 'src/dart_dll.h'));
  final destPath = path.join(destDir.path, 'include', 'dart_dll.h');
  l.info('  ${srcFile.path} => $destPath');
  await srcFile.copy(destPath);

  l.info('Done ✔');
}

void _fetchFromGithub(String? version, Logger l) async {
  final authToken = Platform.environment['GITHUB_TOKEN'];
  final auth = authToken == null
      ? Authentication.anonymous()
      : Authentication.withToken(authToken);
  final github = GitHub(auth: auth);
  final repoSlug = RepositorySlug('fuzzybinary', 'dart_shared_library');

  final Release downloadRelease;
  if (version == null) {
    l.fine('Fetching latest release from github...');
    downloadRelease = await github.repositories.getLatestRelease(repoSlug);
    l.fine('Latest release is ${downloadRelease.name}');
    version = downloadRelease.name;
  } else {
    try {
      downloadRelease =
          await github.repositories.getReleaseByTagName(repoSlug, version);
    } on RepositoryNotFound {
      l.shout(
          '❌ Could not find target release $version. Please check the tag name.');
      return;
    }
  }

  l.info('Downloading artifacts for release $version.');
  if (downloadRelease.assets case final assets?) {
    for (final asset in assets) {
      l.info('  ${asset.browserDownloadUrl}\r');
      final downloadLocation = await _downloadAsset(asset, l);
      await Future.delayed(Duration(milliseconds: 500));
      await _unzipBinaryFiles(downloadLocation, l);
      if (asset.name == 'lib-win.zip') {
        await _unzipIncludeFiles(downloadLocation, l);
      }
    }
  } else {
    l.shout('❌ No assets attached to release $version');
    return;
  }
}

Future<String> _downloadAsset(ReleaseAsset asset, Logger l) async {
  final request = http.Request('GET', Uri.parse(asset.browserDownloadUrl!));
  final response = await http.Client().send(request);

  final writeFile = File(path.join(Directory.systemTemp.path, asset.name!));
  l.fine('Opening temp file... ${writeFile.path}');
  final sink = writeFile.openWrite();

  final totalLength = response.contentLength ?? 0;
  var currentLength = 0;
  final subscription = response.stream.listen((value) {
    currentLength += value.length;
    stdout.write(
        '  ${asset.browserDownloadUrl}  $currentLength / $totalLength\r');
    sink.add(value);
  }, onDone: () {
    sink.close();
  });
  stdout.write('\n');

  await subscription.asFuture();

  return writeFile.path;
}

Future<void> _unzipBinaryFiles(String zipLocation, Logger l) async {
  l.info('Unzipping binary files in $zipLocation');
  final zipStream = InputFileStream(zipLocation);
  final archive = ZipDecoder().decodeBuffer(zipStream);
  for (final file in archive.files) {
    if (file.isFile && file.name.startsWith('bin')) {
      final destPath = path.join(destBinDir.path, path.basename(file.name));
      l.info('  Extracting ${file.name} to $destPath');
      final outputStream = OutputFileStream(destPath);
      file.writeContent(outputStream);
      await outputStream.close();
    }
  }
}

Future<void> _unzipIncludeFiles(String zipLocation, Logger l) async {
  l.info('Unzipping include files in $zipLocation');
  final zipStream = InputFileStream(zipLocation);
  final archive = ZipDecoder().decodeBuffer(zipStream);
  for (final file in archive.files) {
    if (file.isFile && file.name.startsWith('include')) {
      final destPath = path.join(destIncludeDir.path, path.basename(file.name));
      l.info('  Extracting ${file.name} to $destPath');
      final outputStream = OutputFileStream(destPath);
      file.writeContent(outputStream);
      await outputStream.close();
    }
  }
}
