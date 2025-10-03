import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
  final _secureStorage = const FlutterSecureStorage();
  final _picker = ImagePicker();

  final _textController = TextEditingController();
  List<String> _storedKeys = [];
  Uint8List? _decryptedImage;

  static const _imageKeyPrefix = 'img_';
  static const _aesKeyStorageKey = 'aes_key';

  @override
  void initState() {
    super.initState();
    _refreshStoredKeys();
  }

  Future<void> _refreshStoredKeys() async {
    try {
      final all = await _secureStorage.readAll();
      if (!mounted) return;
      setState(() {
        _storedKeys = all.keys
            .where((k) => k.startsWith('secret_') || k.startsWith(_imageKeyPrefix))
            .toList();
      });
    } catch (e) {
      // ignore or log
    }
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _deleteKey(String key) async {
    // if it's an encrypted image, also delete file
    if (key.startsWith(_imageKeyPrefix)) {
      final path = await _secureStorage.read(key: key);
      if (path != null) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
    await _secureStorage.delete(key: key);
    await _refreshStoredKeys();
  }

  // IMAGE encryption helpers
  Future<encrypt_pkg.Key> _getOrCreateAesKey() async {
    final existing = await _secureStorage.read(key: _aesKeyStorageKey);
    if (existing != null) return encrypt_pkg.Key.fromBase64(existing);
    final newKey = encrypt_pkg.Key.fromSecureRandom(32);
    await _secureStorage.write(key: _aesKeyStorageKey, value: newKey.base64);
    return newKey;
  }

  Future<String> _encryptAndSaveImage(XFile file) async {
    final key = await _getOrCreateAesKey();
    final bytes = await file.readAsBytes();
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'secret_img_${DateTime.now().millisecondsSinceEpoch}.enc';
    final out = File('${dir.path}/$fileName');

    final payload = <int>[]..addAll(iv.bytes)..addAll(encrypted.bytes);
    await out.writeAsBytes(payload, flush: true);

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
      await _secureStorage.delete(key: storageKey);
      await _refreshStoredKeys();
      return;
    }

    final data = await file.readAsBytes();
    if (data.length < 16) return;

    final iv = encrypt_pkg.IV(Uint8List.fromList(data.sublist(0, 16)));
    final cipher = data.sublist(16);
    final key = await _getOrCreateAesKey();
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc));

    try {
      final decrypted = encrypter.decryptBytes(encrypt_pkg.Encrypted(Uint8List.fromList(cipher)), iv: iv);
      if (!mounted) return;
      setState(() => _decryptedImage = Uint8List.fromList(decrypted));

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Image'),
          content: _decryptedImage != null ? Image.memory(_decryptedImage!) : const Text('Error decrypting'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      // decrypt error
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to decrypt image.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _decryptedImage = null);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Widget _buildSecretList() {
    if (_storedKeys.isEmpty) {
      return const Center(child: Text('No stored secrets'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
    // VaultScreen assumes caller already authenticated (e.g., HomeScreen)
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Vault')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Secret text or password'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text('Save'), onPressed: _saveTextSecret),
                const SizedBox(width: 12),
                ElevatedButton.icon(icon: const Icon(Icons.photo), label: const Text('Save Image'), onPressed: _pickAndSaveImage),
              ],
            ),
            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text('Stored items', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            _buildSecretList(),
          ],
        ),
      ),
    );
  }
}
