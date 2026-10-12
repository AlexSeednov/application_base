import 'dart:convert';
import 'dart:io';

import 'package:application_base/data/local/service/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// A box the stored key cannot read is set aside rather than left to stop the
/// launch: the key is lost with the keychain or the Keystore, a new one is
/// generated, and the box written under the old key will never open again.
/// Real Hive files in a temporary directory, so the checks run against the
/// hive_ce in use — the detection rests on its error message.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The secure-storage entry the tests keep the key under.
  const cipherKey = 'cipher';

  ///
  const boxName = 'notes';

  ///
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('storage_service_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => directory.path,
        );
  });

  tearDown(() async {
    await Hive.close();
    directory.deleteSync(recursive: true);
  });

  /// A fresh AES key, encoded the way the secure storage keeps it.
  String newKey() => base64UrlEncode(Hive.generateSecureKey());

  /// A service prepared with [key] in the secure storage; `null` leaves the
  /// storage empty, as after a lost key, so the service generates one.
  Future<StorageService> prepared({String? key}) async {
    FlutterSecureStorage.setMockInitialValues({cipherKey: ?key});
    final service = StorageService();
    await service.prepare(cipherKey: cipherKey, registerAdapters: () {});
    return service;
  }

  /// Files left beside the boxes under a set-aside name.
  List<File> setAsideFiles() => directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.contains('.unreadable-'))
      .toList();

  /// Writes one record into the box under [key] and closes Hive.
  Future<void> writeRecord(String key) async {
    final StorageService service = await prepared(key: key);
    final Box<String> box = await service.open<String>(boxName);
    await box.put('record', 'kept');
    await Hive.close();
  }

  test('a box opens with its records under its own key', () async {
    final String key = newKey();
    await writeRecord(key);

    final StorageService service = await prepared(key: key);
    final Box<String> box = await service.open<String>(boxName);

    expect(box.get('record'), 'kept');
    expect(setAsideFiles(), isEmpty);
  });

  test('a box the key cannot read is set aside for an empty one', () async {
    await writeRecord(newKey());

    final StorageService service = await prepared();
    final Box<String> box = await service.open<String>(boxName);

    expect(box.isEmpty, isTrue);
    expect(setAsideFiles(), hasLength(1));

    // The new box is usable: what is written there reads back.
    await box.put('record', 'new');
    expect(box.get('record'), 'new');
  });

  test('a set-aside box opens again once its key is back', () async {
    final String key = newKey();
    await writeRecord(key);

    await (await prepared()).open<String>(boxName);
    await Hive.close();

    final File setAside = setAsideFiles().single;
    final String boxPath = [
      directory.path,
      '$boxName.hive',
    ].join(Platform.pathSeparator);
    File(boxPath).deleteSync();
    setAside.renameSync(boxPath);

    final StorageService service = await prepared(key: key);
    final Box<String> box = await service.open<String>(boxName);

    expect(box.get('record'), 'kept');
  });

  test('a box with an unknown type is not taken for a lost key', () async {
    final String key = newKey();
    final StorageService writer = await prepared(key: key);
    Hive.registerAdapter(_NoteAdapter());
    final Box<_Note> written = await writer.open<_Note>(boxName);
    await written.put('record', const _Note('kept'));
    await Hive.close();

    final String boxPath = [
      directory.path,
      '$boxName.hive',
    ].join(Platform.pathSeparator);
    final int length = File(boxPath).lengthSync();

    // The build that reads the box lacks the adapter. This also drops the
    // default adapters, which no test here needs: they store strings.
    Hive.resetAdapters();
    final StorageService reader = await prepared(key: key);

    await expectLater(reader.open<_Note>(boxName), throwsA(isA<HiveError>()));
    expect(setAsideFiles(), isEmpty);
    expect(File(boxPath).lengthSync(), length);
  });
}

/// A stored type with an adapter of its own, so a build can lack it.
final class _Note {
  ///
  const _Note(this.text);

  ///
  final String text;
}

///
final class _NoteAdapter extends TypeAdapter<_Note> {
  ///
  @override
  final int typeId = 1;

  ///
  @override
  _Note read(BinaryReader reader) => _Note(reader.readString());

  ///
  @override
  void write(BinaryWriter writer, _Note obj) => writer.writeString(obj.text);
}
