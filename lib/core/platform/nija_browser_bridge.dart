import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('nijaBrowser.readIndexedText')
external JSPromise<JSAny?> _readIndexedText(
  JSString dbName,
  JSString storeName,
  JSString key,
  JSNumber version,
);

@JS('nijaBrowser.writeIndexedText')
external JSPromise<JSBoolean> _writeIndexedText(
  JSString dbName,
  JSString storeName,
  JSString key,
  JSString value,
  JSNumber version,
);

@JS('nijaBrowser.deleteIndexedText')
external JSPromise<JSBoolean> _deleteIndexedText(
  JSString dbName,
  JSString storeName,
  JSString key,
  JSNumber version,
);

@JS('nijaBrowser.readLocalText')
external JSString? _readLocalText(JSString key);

@JS('nijaBrowser.removeLocalText')
external void _removeLocalText(JSString key);

@JS('nijaBrowser.pickTextFile')
external JSPromise<JSObject?> _pickTextFile(JSString accept);

@JS('nijaBrowser.downloadTextFile')
external JSBoolean _downloadTextFile(
  JSString fileName,
  JSString content,
  JSString mimeType,
);

@JS('nijaBrowser.downloadBase64File')
external JSBoolean _downloadBase64File(
  JSString fileName,
  JSString base64,
  JSString mimeType,
);

@JS('nijaBrowser.shareTextFile')
external JSPromise<JSBoolean> _shareTextFile(
  JSString fileName,
  JSString content,
  JSString mimeType,
);

@JS('nijaBrowser.shareBase64File')
external JSPromise<JSBoolean> _shareBase64File(
  JSString fileName,
  JSString base64,
  JSString mimeType,
);

@JS('nijaBrowser.pwaStatus')
external JSObject _pwaStatus();

@JS('nijaBrowser.promptPwaInstall')
external JSPromise<JSObject?> _promptPwaInstall();

@JS('nijaBrowser.webAuthnIsAvailable')
external JSPromise<JSBoolean> _webAuthnIsAvailable();

@JS('nijaBrowser.webAuthnIsSupported')
external JSPromise<JSBoolean> _webAuthnIsSupported();

@JS('nijaBrowser.webAuthnSupportsPrf')
external JSPromise<JSBoolean> _webAuthnSupportsPrf();

@JS('nijaBrowser.webAuthnRegisterQuickUnlock')
external JSPromise<JSObject?> _webAuthnRegisterQuickUnlock(
  JSString vaultId,
  JSString displayName,
);

@JS('nijaBrowser.webAuthnAuthenticateQuickUnlock')
external JSPromise<JSObject?> _webAuthnAuthenticateQuickUnlock(
  JSString credentialId,
  JSString prfSalt,
);

class NijaPickedTextFile {
  const NijaPickedTextFile({required this.name, required this.content});

  final String name;
  final String content;
}

class NijaPwaBrowserStatus {
  const NijaPwaBrowserStatus({
    required this.isInstalled,
    required this.canPrompt,
    required this.requiresManualSteps,
    required this.platform,
  });

  final bool isInstalled;
  final bool canPrompt;
  final bool requiresManualSteps;
  final String platform;
}

class NijaWebAuthnRegistration {
  const NijaWebAuthnRegistration({
    required this.credentialId,
    required this.prfSalt,
    required this.prfKey,
  });

  final String credentialId;
  final String prfSalt;
  final String prfKey;
}

class NijaWebAuthnAuthentication {
  const NijaWebAuthnAuthentication({required this.ok, required this.prfKey});

  final bool ok;
  final String prfKey;
}

Future<String?> nijaReadIndexedText({
  required String dbName,
  required String storeName,
  required String key,
  int version = 1,
}) async {
  final result = await _readIndexedText(
    dbName.toJS,
    storeName.toJS,
    key.toJS,
    version.toJS,
  ).toDart;
  if (result == null) return null;
  return (result as JSString).toDart;
}

Future<void> nijaWriteIndexedText({
  required String dbName,
  required String storeName,
  required String key,
  required String value,
  int version = 1,
}) async {
  await _writeIndexedText(
    dbName.toJS,
    storeName.toJS,
    key.toJS,
    value.toJS,
    version.toJS,
  ).toDart;
}

Future<void> nijaDeleteIndexedText({
  required String dbName,
  required String storeName,
  required String key,
  int version = 1,
}) async {
  await _deleteIndexedText(
    dbName.toJS,
    storeName.toJS,
    key.toJS,
    version.toJS,
  ).toDart;
}

String? nijaReadLocalText(String key) => _readLocalText(key.toJS)?.toDart;

void nijaRemoveLocalText(String key) => _removeLocalText(key.toJS);

Future<NijaPickedTextFile?> nijaPickTextFile(String accept) async {
  final result = await _pickTextFile(accept.toJS).toDart;
  if (result == null) return null;
  final name = result.getProperty<JSString>('name'.toJS).toDart;
  final content = result.getProperty<JSString>('content'.toJS).toDart;
  if (content.isEmpty) return null;
  return NijaPickedTextFile(name: name, content: content);
}

bool nijaDownloadTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) {
  return _downloadTextFile(fileName.toJS, content.toJS, mimeType.toJS).toDart;
}

bool nijaDownloadBase64File({
  required String fileName,
  required String base64,
  required String mimeType,
}) {
  return _downloadBase64File(fileName.toJS, base64.toJS, mimeType.toJS).toDart;
}

Future<bool> nijaShareTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  return (await _shareTextFile(
    fileName.toJS,
    content.toJS,
    mimeType.toJS,
  ).toDart).toDart;
}

Future<bool> nijaShareBase64File({
  required String fileName,
  required String base64,
  required String mimeType,
}) async {
  return (await _shareBase64File(
    fileName.toJS,
    base64.toJS,
    mimeType.toJS,
  ).toDart).toDart;
}

NijaPwaBrowserStatus nijaPwaStatus() {
  final result = _pwaStatus();
  return NijaPwaBrowserStatus(
    isInstalled: result.getProperty<JSBoolean>('isInstalled'.toJS).toDart,
    canPrompt: result.getProperty<JSBoolean>('canPrompt'.toJS).toDart,
    requiresManualSteps: result
        .getProperty<JSBoolean>('requiresManualSteps'.toJS)
        .toDart,
    platform: result.getProperty<JSString>('platform'.toJS).toDart,
  );
}

Future<String?> nijaPromptPwaInstall() async {
  final result = await _promptPwaInstall().toDart;
  return result?.getProperty<JSString>('outcome'.toJS).toDart;
}

Future<bool> nijaWebAuthnIsAvailable() async {
  return (await _webAuthnIsAvailable().toDart).toDart;
}

Future<bool> nijaWebAuthnIsSupported() async {
  return (await _webAuthnIsSupported().toDart).toDart;
}

Future<bool> nijaWebAuthnSupportsPrf() async {
  return (await _webAuthnSupportsPrf().toDart).toDart;
}

Future<NijaWebAuthnRegistration?> nijaWebAuthnRegisterQuickUnlock({
  required String vaultId,
  required String displayName,
}) async {
  final result = await _webAuthnRegisterQuickUnlock(
    vaultId.toJS,
    displayName.toJS,
  ).toDart;
  if (result == null) return null;
  return NijaWebAuthnRegistration(
    credentialId: result.getProperty<JSString>('credentialId'.toJS).toDart,
    prfSalt: result.getProperty<JSString>('prfSalt'.toJS).toDart,
    prfKey: result.getProperty<JSString>('prfKey'.toJS).toDart,
  );
}

Future<NijaWebAuthnAuthentication?> nijaWebAuthnAuthenticateQuickUnlock({
  required String credentialId,
  required String prfSalt,
}) async {
  final result = await _webAuthnAuthenticateQuickUnlock(
    credentialId.toJS,
    prfSalt.toJS,
  ).toDart;
  if (result == null) return null;
  return NijaWebAuthnAuthentication(
    ok: result.getProperty<JSBoolean>('ok'.toJS).toDart,
    prfKey: result.getProperty<JSString>('prfKey'.toJS).toDart,
  );
}
