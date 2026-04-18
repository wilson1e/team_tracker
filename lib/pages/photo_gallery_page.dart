import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_plan_service.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// 照片相簿頁面
class PhotoGalleryPage extends StatefulWidget {
  final String teamName;
  final String? inviteCode;
  final String? ownerUid;

  const PhotoGalleryPage({
    super.key,
    required this.teamName,
    this.inviteCode,
    this.ownerUid,
  });

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;
  int _maxPhotos = 50;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = widget.ownerUid ?? user.uid;
      final teamId = widget.inviteCode ?? widget.teamName;

      // 讀取訂閱限制
      final limits = await UserPlanService.fetchLimits(uid);
      if (mounted) setState(() => _maxPhotos = limits['maxPhotos'] as int);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('teams')
          .doc(teamId)
          .collection('photos')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _photos = snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data(),
          }).toList();
        });
      }
    } catch (e) {
      print('載入照片失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_photos.length >= _maxPhotos) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('照片上限', style: TextStyle(color: Colors.white)),
          content: Text(
            '您目前最多可上傳 $_maxPhotos 張照片。\n如需更多配額，請升級訂閱。',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;
      await _uploadPhoto(image);
    } catch (e) {
      debugPrint('選擇照片失敗: $e');
    }
  }

  Future<void> _uploadPhoto(XFile image) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = widget.ownerUid ?? user.uid;
    final teamId = widget.inviteCode ?? widget.teamName;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'teams/$uid/$teamId/photos/$fileName';

    try {
      // Show uploading indicator
      if (mounted) setState(() => _isLoading = true);

      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putFile(File(image.path));
      final downloadUrl = await ref.getDownloadURL();

      // Save URL to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('teams')
          .doc(teamId)
          .collection('photos')
          .add({
        'url': downloadUrl,
        'storagePath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': user.displayName ?? user.email,
      });

      await _loadPhotos();
    } catch (e) {
      debugPrint('上傳照片失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上傳失敗，請稍後再試'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: Text('${widget.teamName} 相簿'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _photos.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) => _buildPhotoCard(_photos[index]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImage,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add_photo_alternate),
        label: Text('上傳照片 (${_photos.length}/$_maxPhotos)'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 80, color: Colors.white.withValues(alpha:0.2)),
          const SizedBox(height: 16),
          const Text('暫時未有照片', style: TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('點擊下方按鈕上傳照片', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo) {
    final url = photo['url'] as String?;

    return GestureDetector(
      onTap: () => _showPhotoDetail(photo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url != null
            ? Image.network(url, fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, color: Colors.white38),
                ),
              )
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.broken_image, color: Colors.white38),
              ),
      ),
    );
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = widget.ownerUid ?? user.uid;
    final teamId = widget.inviteCode ?? widget.teamName;
    try {
      final storagePath = photo['storagePath'] as String?;
      if (storagePath != null) {
        await FirebaseStorage.instance.ref(storagePath).delete();
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('teams')
          .doc(teamId)
          .collection('photos')
          .doc(photo['id'] as String)
          .delete();
      await _loadPhotos();
    } catch (e) {
      debugPrint('刪除照片失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('刪除失敗，請稍後再試'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPhotoDetail(Map<String, dynamic> photo) {
    final url = photo['url'] as String?;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (url != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '上傳者: ${photo['uploadedBy'] ?? "未知"}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _deletePhoto(photo);
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('刪除照片', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
