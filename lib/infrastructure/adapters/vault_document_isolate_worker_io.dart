import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

Future<List<int>> decryptCipherWorker({
  required List<int> cipher,
  required List<int> key,
}) {
  return _PersistentCryptoIsolate.instance.decrypt(cipher: cipher, key: key);
}

Future<List<int>> encryptCipherWorker({
  required List<int> plain,
  required List<int> key,
  required List<int> nonce,
}) {
  return _PersistentCryptoIsolate.instance.encrypt(
    plain: plain,
    key: key,
    nonce: nonce,
  );
}

class _PersistentCryptoIsolate {
  _PersistentCryptoIsolate._();

  static final _PersistentCryptoIsolate instance = _PersistentCryptoIsolate._();

  SendPort? _workerPort;
  Future<SendPort>? _starting;
  int _nextId = 1;
  final Map<int, Completer<Uint8List>> _pending =
      <int, Completer<Uint8List>>{};

  Future<SendPort> _ensureStarted() {
    final existing = _workerPort;
    if (existing != null) return Future<SendPort>.value(existing);
    final inFlight = _starting;
    if (inFlight != null) return inFlight;

    final completer = Completer<SendPort>();
    _starting = completer.future;

    final receivePort = ReceivePort();
    receivePort.listen((message) {
      if (message is SendPort) {
        _workerPort = message;
        if (!completer.isCompleted) {
          completer.complete(message);
        }
        return;
      }
      if (message is List && message.length >= 2 && message[0] is int) {
        final id = message[0] as int;
        final pending = _pending.remove(id);
        if (pending == null) return;
        if (message[1] is TransferableTypedData) {
          final bytes =
              (message[1] as TransferableTypedData).materialize().asUint8List();
          pending.complete(bytes);
        } else {
          pending.completeError(
            StateError(message.length >= 3 ? '${message[2]}' : 'Crypto error'),
          );
        }
      }
    });

    Isolate.spawn(_cryptoWorkerEntry, receivePort.sendPort).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _starting = null;
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      throw error;
    });

    return completer.future;
  }

  Future<Uint8List> decrypt({
    required List<int> cipher,
    required List<int> key,
  }) async {
    final port = await _ensureStarted();
    final id = _nextId++;
    final completer = Completer<Uint8List>();
    _pending[id] = completer;
    port.send(<Object>[
      id,
      'decrypt',
      TransferableTypedData.fromList([Uint8List.fromList(cipher)]),
      TransferableTypedData.fromList([Uint8List.fromList(key)]),
    ]);
    return completer.future;
  }

  Future<Uint8List> encrypt({
    required List<int> plain,
    required List<int> key,
    required List<int> nonce,
  }) async {
    final port = await _ensureStarted();
    final id = _nextId++;
    final completer = Completer<Uint8List>();
    _pending[id] = completer;
    port.send(<Object>[
      id,
      'encrypt',
      TransferableTypedData.fromList([Uint8List.fromList(plain)]),
      TransferableTypedData.fromList([Uint8List.fromList(key)]),
      TransferableTypedData.fromList([Uint8List.fromList(nonce)]),
    ]);
    return completer.future;
  }
}

void _cryptoWorkerEntry(SendPort mainPort) {
  final workerPort = ReceivePort();
  mainPort.send(workerPort.sendPort);
  final algorithm = AesGcm.with256bits();

  workerPort.listen((message) async {
    if (message is! List || message.length < 4) return;
    final id = message[0] as int;
    final op = message[1] as String;
    try {
      if (op == 'decrypt') {
        const nonceLength = 12;
        const macLength = 16;
        final cipher =
            (message[2] as TransferableTypedData).materialize().asUint8List();
        final key =
            (message[3] as TransferableTypedData).materialize().asUint8List();
        if (cipher.length < nonceLength + macLength) {
          throw StateError('Ciphertext is too short.');
        }
        final nonce = cipher.sublist(0, nonceLength);
        final macStart = cipher.length - macLength;
        final ciphertext = cipher.sublist(nonceLength, macStart);
        final macBytes = cipher.sublist(macStart);
        final secretBox = SecretBox(
          ciphertext,
          nonce: nonce,
          mac: Mac(macBytes),
        );
        final plain = await algorithm.decrypt(
          secretBox,
          secretKey: SecretKey(key),
        );
        mainPort.send(<Object>[
          id,
          TransferableTypedData.fromList([Uint8List.fromList(plain)]),
        ]);
        return;
      }

      if (op == 'encrypt' && message.length >= 5) {
        final plain =
            (message[2] as TransferableTypedData).materialize().asUint8List();
        final key =
            (message[3] as TransferableTypedData).materialize().asUint8List();
        final nonce =
            (message[4] as TransferableTypedData).materialize().asUint8List();
        final secretBox = await algorithm.encrypt(
          plain,
          secretKey: SecretKey(key),
          nonce: nonce,
        );
        final out = Uint8List(
          nonce.length +
              secretBox.cipherText.length +
              secretBox.mac.bytes.length,
        );
        out.setRange(0, nonce.length, nonce);
        out.setRange(
          nonce.length,
          nonce.length + secretBox.cipherText.length,
          secretBox.cipherText,
        );
        out.setRange(
          nonce.length + secretBox.cipherText.length,
          out.length,
          secretBox.mac.bytes,
        );
        mainPort.send(<Object>[
          id,
          TransferableTypedData.fromList([out]),
        ]);
        return;
      }
      mainPort.send(<Object>[id, false, 'Unsupported crypto operation']);
    } catch (error) {
      mainPort.send(<Object>[id, false, '$error']);
    }
  });
}
