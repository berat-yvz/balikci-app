import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/services/supabase_service.dart';
import '../../../data/repositories/fish_log_repository.dart';

class AddLogScreen extends ConsumerStatefulWidget {
  const AddLogScreen({super.key});

  @override
  ConsumerState<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends ConsumerState<AddLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedFishType;
  bool _isPrivate = false;
  bool _isReleased = false;
  bool _isLoading = false;
  File? _selectedImage;

  static const List<String> _fishTypes = [
    'Levrek',
    'Çipura',
    'Saroz',
    'Palamut',
    'Lüfer',
    'Kefal',
    'Alabalık',
    'Sazan',
    'Turna',
    'Zargana',
    'İstavrit',
    'Hamsi',
    'Kolyoz',
    'Orfoz',
    'Lahoz',
    'Diğer',
  ];

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<String?> _uploadPhoto(File file) async {
    try {
      final userId = SupabaseService.auth.currentUser?.id ?? 'unknown';
      final fileName =
          'fish_logs/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.storage
          .from('fish-photos')
          .upload(fileName, file);
      return SupabaseService.storage
          .from('fish-photos')
          .getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFishType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen balık türü seçin',
              style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.auth.currentUser?.id ?? '';

      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await _uploadPhoto(_selectedImage!);
      }

      await FishLogRepository().createLog(
        userId: userId,
        species: _selectedFishType!,
        weightKg: _weightController.text.isNotEmpty
            ? double.tryParse(_weightController.text)
            : null,
        lengthCm: _lengthController.text.isNotEmpty
            ? double.tryParse(_lengthController.text)
            : null,
        photoUrl: photoUrl,
        notes: _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
        isPrivate: _isPrivate,
        released: _isReleased,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt eklendi! 🎣',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt eklenemedi, tekrar deneyin',
                style: TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🎣 Yeni Balık Kaydı',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Fotoğraf seç
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 56, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Fotoğraf Ekle',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // Balık türü seç
            const Text(
              'Balık Türü *',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0F6E56), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFishType,
                  hint: const Text('Balık seçin...',
                      style: TextStyle(fontSize: 18)),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 32),
                  items: _fishTypes
                      .map((fish) => DropdownMenuItem(
                            value: fish,
                            child: Text(fish,
                                style: const TextStyle(fontSize: 18)),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedFishType = val),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ağırlık ve Uzunluk yan yana
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ağırlık (kg)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: const TextStyle(fontSize: 18),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.shade400, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F6E56), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Uzunluk (cm)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lengthController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: const TextStyle(fontSize: 18),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.shade400, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F6E56), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Geri bıraktım toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isReleased
                    ? Colors.blue.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isReleased
                      ? Colors.blue.shade300
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.water, size: 32, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Geri bıraktım 🐟',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                  ),
                  Transform.scale(
                    scale: 1.3,
                    child: Switch(
                      value: _isReleased,
                      onChanged: (val) =>
                          setState(() => _isReleased = val),
                      activeThumbColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Gizli kayıt toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isPrivate
                    ? Colors.orange.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPrivate
                      ? Colors.orange.shade300
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 32,
                      color: Colors.orange),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Gizli kayıt',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                  ),
                  Transform.scale(
                    scale: 1.3,
                    child: Switch(
                      value: _isPrivate,
                      onChanged: (val) =>
                          setState(() => _isPrivate = val),
                      activeThumbColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Not alanı
            const Text(
              'Not (isteğe bağlı)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Nasıl bir gündü? Ne yedirdin?',
                hintStyle:
                    const TextStyle(fontSize: 16, color: Colors.grey),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade400, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF0F6E56), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Kaydet butonu
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F6E56),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save, size: 28),
                label: Text(
                  _isLoading ? 'Kaydediliyor...' : 'KAYDET',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
