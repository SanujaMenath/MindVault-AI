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
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }
    final key = 'secret_${DateTime.now().millisecondsSinceEpoch}';
    await _secureStorage.write(key: key, value: text);
    _textController.clear();
    await _refreshStoredKeys();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secret saved securely'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _viewTextSecret(String key) async {
    final val = await _secureStorage.read(key: key) ?? '';
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lock_open, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Secret'),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: SelectableText(
              val,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item deleted'),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
    
    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Encrypting image...')),
      );
    }
    
    await _encryptAndSaveImage(picked);
    
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image encrypted and saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
      final decrypted = encrypter.decryptBytes(
        encrypt_pkg.Encrypted(Uint8List.fromList(cipher)),
        iv: iv,
      );
      if (!mounted) return;
      setState(() => _decryptedImage = Uint8List.fromList(decrypted));

      await showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.image, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Decrypted Image',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (_decryptedImage != null)
                Container(
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: Image.memory(_decryptedImage!, fit: BoxFit.contain),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Error decrypting'),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Error'),
          content: const Text('Failed to decrypt image.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No stored secrets',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add text or images to secure them',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _storedKeys.length,
      itemBuilder: (context, index) {
        final k = _storedKeys[index];
        final isImage = k.startsWith(_imageKeyPrefix);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isImage
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isImage ? Icons.image : Icons.lock,
                color: isImage ? Colors.orange : Colors.deepPurple,
                size: 24,
              ),
            ),
            title: Text(
              isImage ? 'Encrypted Image' : 'Secret Text',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              'Tap to view',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility),
                  color: Colors.blue,
                  onPressed: () async {
                    if (isImage) {
                      await _decryptAndShowImage(k);
                    } else {
                      await _viewTextSecret(k);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  onPressed: () => _deleteKey(k),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          'Safe Vault',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 255, 136, 0),
                    Color.fromARGB(255, 204, 85, 0),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.security, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All items are encrypted and stored securely',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Input section
            Text(
              'Add New Secret',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 3,
              style: TextStyle(
                color: theme.brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Secret text or password',
                hintText: 'Enter your secret...',
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple),
                labelStyle: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[700],
                ),
                hintStyle: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[500]
                      : Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Text'),
                    onPressed: _saveTextSecret,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Save Image'),
                    onPressed: _pickAndSaveImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Stored items section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stored Items',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                if (_storedKeys.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_storedKeys.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSecretList(),
          ],
        ),
      ),
    );
  }
}