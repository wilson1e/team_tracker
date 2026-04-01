import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // TODO: 上傳到 Firebase Storage
      // 目前先儲存路徑到 Firestore
      await _savePhoto(image.path);
    } catch (e) {
      print('選擇照片失敗: $e');
    }
  }

  Future<void> _savePhoto(String path) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = widget.ownerUid ?? user.uid;
      final teamId = widget.inviteCode ?? widget.teamName;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('teams')
          .doc(teamId)
          .collection('photos')
          .add({
        'path': path,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': user.displayName ?? user.email,
      });

      _loadPhotos();
    } catch (e) {
      print('儲存照片失敗: $e');
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
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('暫時未有照片', style: TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('點擊下方按鈕上傳照片', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo) {
    final path = photo['path'] as String;
    final file = File(path);

    return GestureDetector(
      onTap: () => _showPhotoDetail(photo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.broken_image, color: Colors.white38),
              ),
      ),
    );
  }

  void _showPhotoDetail(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(photo['path'] as String)),
            ),
            const SizedBox(height: 16),
            Text(
              '上傳者: ${photo['uploadedBy'] ?? "未知"}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
