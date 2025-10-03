import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:path_provider/path_provider.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _auth = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage();
  final _picker = ImagePicker();

  final _textController = TextEditingController();
  List<String> _storedKeys = [];
  bool _unlocked = false;
  Uint8List? _decryptedImage;

  static const _imageKeyPrefix = 'img_';
  static const _aesKeyStorageKey =
      'aes_key'; // store AES key wrapped by platform secure storage

  @override
  void initState() {
    super.initState();
    _authenticateAndLoad();
  }

  Future<void> _authenticateAndLoad() async {
    try {
      final canCheck =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        // no biometrics, you can choose to fallback to PIN or block access
        await _showErrorAndPop('Biometric auth not available on this device.');
        return;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock Secrets (use fingerprint or face)',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      if (!didAuthenticate) {
        // deny access
        await _showErrorAndPop('Authentication failed.');
        return;
      }

      // success
      setState(() => _unlocked = true);
      await _refreshStoredKeys();
    } catch (e) {
      await _showErrorAndPop('Auth error: $e');
    }
  }

  Future<void> _showErrorAndPop(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Access denied'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _refreshStoredKeys() async {
    final all = await _secureStorage.readAll();
    // filter keys we use for secrets
    setState(() {
      _storedKeys = all.keys
          .where(
            (k) => k.startsWith('secret_') || k.startsWith(_imageKeyPrefix),
          )
          .toList();
    });
  }

  // TEXT secret methods
  Future<void> _saveTextSecret() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final key = 'secret_${DateTime.now().millisecondsSinceEpoch}';
    await _secureStorage.write(key: key, value: text);
    _textController.clear();
    await _refreshStoredKeys();
  }

  Future<void> _viewTextSecret(String key) async {
    final val = await _secureStorage.read(key: key) ?? '';
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Secret'),
        content: SingleChildScrollView(child: Text(val)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteKey(String key) async {
    await _secureStorage.delete(key: key);
    await _refreshStoredKeys();
  }

  // IMAGE encryption helpers
  Future<encrypt_pkg.Key> _getOrCreateAesKey() async {
    final existing = await _secureStorage.read(key: _aesKeyStorageKey);
    if (existing != null) {
      // stored as base64
      return encrypt_pkg.Key.fromBase64(existing);
    }
    // generate random 32 bytes AES key
    final newKey = encrypt_pkg.Key.fromSecureRandom(32);
    await _secureStorage.write(key: _aesKeyStorageKey, value: newKey.base64);
    return newKey;
  }

  Future<String> _encryptAndSaveImage(XFile file) async {
    final key = await _getOrCreateAesKey();
    final bytes = await file.readAsBytes();
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc),
    );
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'secret_img_${DateTime.now().millisecondsSinceEpoch}.enc';
    final out = File('${dir.path}/$fileName');
    // store IV + ciphertext (we'll save iv + cipher bytes)
    final payload = <int>[]
      ..addAll(iv.bytes)
      ..addAll(encrypted.bytes);
    await out.writeAsBytes(payload, flush: true);

    // store mapping key to file path
    final storageKey = '$_imageKeyPrefix$fileName';
    await _secureStorage.write(key: storageKey, value: out.path);
    await _refreshStoredKeys();
    return storageKey;
  }

  Future<void> _pickAndSaveImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _encryptAndSaveImage(picked);
  }

  Future<void> _decryptAndShowImage(String storageKey) async {
    final path = await _secureStorage.read(key: storageKey);
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) {
      // cleanup
      await _secureStorage.delete(key: storageKey);
      await _refreshStoredKeys();
      return;
    }
    final data = await file.readAsBytes();
    if (data.length < 16) return;
    final iv = encrypt_pkg.IV(Uint8List.fromList(data.sublist(0, 16)));
    final cipher = data.sublist(16);
    final key = await _getOrCreateAesKey();
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc),
    );
    final decrypted = encrypter.decryptBytes(
      encrypt_pkg.Encrypted(Uint8List.fromList(cipher)),
      iv: iv,
    );

    setState(() {
      _decryptedImage = Uint8List.fromList(decrypted);
    });

    // show image preview
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Image'),
        content: _decryptedImage != null
            ? Image.memory(_decryptedImage!)
            : const Text('Error decrypting'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    setState(() => _decryptedImage = null);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Widget _buildSecretList() {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _storedKeys.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final k = _storedKeys[index];
        final isImage = k.startsWith(_imageKeyPrefix);
        return ListTile(
          leading: Icon(isImage ? Icons.image : Icons.lock),
          title: Text(isImage ? 'Hidden image' : 'Secret text'),
          subtitle: Text(k),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () async {
                  if (isImage) {
                    await _decryptAndShowImage(k);
                  } else {
                    await _viewTextSecret(k);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteKey(k),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Safe Vault')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // save text secret
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Secret text or password',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: _saveTextSecret,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text('Save Image'),
                  onPressed: _pickAndSaveImage,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Stored items',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _buildSecretList(),
          ],
        ),
      ),
    );
  }
}
