import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'web_integrity_manifest.dart';

class NijaWebIntegrityKeyPair {
  const NijaWebIntegrityKeyPair({
    required this.seedBase64,
    required this.publicKeyBase64,
  });

  final String seedBase64;
  final String publicKeyBase64;
}

Future<NijaWebIntegrityKeyPair> generateNijaWebIntegrityTestKeyPair() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final seed = await keyPair.extractPrivateKeyBytes();
  final publicKey = await keyPair.extractPublicKey();
  return NijaWebIntegrityKeyPair(
    seedBase64: base64Encode(seed),
    publicKeyBase64: base64Encode(publicKey.bytes),
  );
}

Future<String> signNijaWebIntegrityManifest({
  required NijaWebIntegrityManifest manifest,
  required String privateSeedBase64,
}) async {
  manifest.validate();
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(
    base64Decode(privateSeedBase64.trim()),
  );
  final signature = await algorithm.sign(
    manifest.canonicalBytes(),
    keyPair: keyPair,
  );
  return base64Encode(signature.bytes);
}

Future<bool> verifyNijaWebIntegrityManifestSignature({
  required NijaWebIntegrityManifest manifest,
  required String signatureBase64,
  required String publicKeyBase64,
}) async {
  manifest.validate();
  final signature = signatureBase64.trim();
  final publicKey = publicKeyBase64.trim();
  if (signature.isEmpty || publicKey.isEmpty) return false;
  try {
    final algorithm = Ed25519();
    return algorithm.verify(
      manifest.canonicalBytes(),
      signature: Signature(
        base64Decode(signature),
        publicKey: SimplePublicKey(
          Uint8List.fromList(base64Decode(publicKey)),
          type: KeyPairType.ed25519,
        ),
      ),
    );
  } catch (_) {
    return false;
  }
}
