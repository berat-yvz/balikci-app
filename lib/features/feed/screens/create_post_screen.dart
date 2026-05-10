import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/error_message_helper.dart';
import 'package:balikci_app/core/utils/avatar_image_prepare.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';

/// Sık seçilen balık türleri — gönderi ekranında chip olarak.
const List<String> _kCommonFishSpecies = [
  'Lüfer',
  'Çipura',
  'Levrek',
  'Hamsi',
  'Palamut',
  'Kefal',
  'İstavrit',
  'Kofana',
];

/// Gönderi oluşturma — tek sayfa: fotoğraf, balık chip'leri, yazı, mera, paylaş.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _fishExtraController = TextEditingController();
  final _spotRepo = SpotRepository();

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  final Set<String> _selectedFish = {};

  /// Seçili meranın ID'si; null = mera gösterme.
  String? _selectedSpotId;
  List<SpotModel> _userSpots = [];
  bool _loadingSpots = false;
  bool _spotsLoaded = false;
  bool _uploading = false;

  bool get _hasPhoto => _pickedImage != null;

  @override
  void dispose() {
    _captionController.dispose();
    _fishExtraController.dispose();
    super.dispose();
  }

  void _toggleFish(String species) {
    setState(() {
      if (_selectedFish.contains(species)) {
        _selectedFish.remove(species);
      } else {
        _selectedFish.add(species);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 75,
      );
      if (picked == null || !mounted) return;
      Uint8List? bytes;
      if (kIsWeb) bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _previewBytes = bytes;
      });
      await _loadSpotsIfNeeded();
    } catch (e, st) {
      debugPrint('pickImage ($source): $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMessageHelper.toUserMessage(
              e,
              fallback: 'Fotoğraf seçilemedi. Tekrar dene.',
            ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showChangePhotoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Yeni fotoğraf çek'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Galeriden seç'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSpotsIfNeeded() async {
    if (_spotsLoaded || _loadingSpots) return;
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _loadingSpots = true);
    try {
      final spots = await _spotRepo.getSpotsByUserId(uid);
      if (mounted) {
        setState(() {
          _userSpots = spots;
          _spotsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _spotsLoaded = true);
    } finally {
      if (mounted) setState(() => _loadingSpots = false);
    }
  }

  SpotModel? _resolvedSpot() {
    final id = _selectedSpotId;
    if (id == null) return null;
    for (final s in _userSpots) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool get _showPrivateSpotNotice {
    final spot = _resolvedSpot();
    return spot != null &&
        (spot.privacyLevel == 'private' || spot.privacyLevel == 'vip');
  }

  /// Açılır liste için geçerli seçim (liste yenilenince silinmiş ID kalmasın).
  String? get _effectiveSpotIdForDropdown {
    final id = _selectedSpotId;
    if (id == null) return null;
    return _userSpots.any((s) => s.id == id) ? id : null;
  }

  Future<String> _uploadPhoto() async {
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Oturum bulunamadı — lütfen tekrar giriş yapın');
    }
    final path = '$uid/posts/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await prepareAvatarUploadBytes(_pickedImage!);
    await SupabaseService.storage.from(AppConstants.photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return SupabaseService.storage
        .from(AppConstants.photoBucket)
        .getPublicUrl(path);
  }

  List<String>? _combinedFishSpecies() {
    final extraRaw = _fishExtraController.text.trim();
    final fromExtra = extraRaw.isEmpty
        ? <String>[]
        : extraRaw
            .split(RegExp(r'[,;]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    final merged = {..._selectedFish, ...fromExtra}.toList();
    if (merged.isEmpty) return null;
    merged.sort();
    return merged;
  }

  Future<void> _share() async {
    if (!_hasPhoto || _uploading) return;
    setState(() => _uploading = true);
    try {
      late final String photoUrl;
      try {
        photoUrl = await _uploadPhoto();
      } catch (e, st) {
        debugPrint('GÖNDERI STORAGE HATA: $e\n$st');
        if (!mounted) return;
        final text = ErrorMessageHelper.isNetworkError(e)
            ? ErrorMessageHelper.toUserMessage(e)
            : ErrorMessageHelper.toUserMessage(
                e,
                fallback:
                    'Fotoğraf yüklenemedi, internet bağlantını kontrol et',
              );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      await ref.read(postRepositoryProvider).createPost(
            photoUrl: photoUrl,
            caption: _captionController.text.trim().isEmpty
                ? null
                : _captionController.text.trim(),
            fishSpecies: _combinedFishSpecies(),
            spotId: _resolvedSpot()?.id,
            spotDistrict: _resolvedSpot()?.privacyLevel == 'vip'
                ? null
                : _resolvedSpot()?.description,
          );
      ref.invalidate(globalFeedProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paylaşıldı'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e, st) {
      debugPrint('GÖNDERI PAYLAŞ HATA: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMessageHelper.toUserMessage(
              e,
              fallback: 'Bir sorun oluştu, lütfen tekrar dene',
            ),
          ),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Kapat',
        ),
        title: Text(_hasPhoto ? 'Yeni gönderi' : 'Fotoğraf ekle'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _hasPhoto
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.muted.withValues(alpha: 0.35),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: !_hasPhoto
                            ? const _PhotoPlaceholder()
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  _PhotoPreview(
                                    pickedImage: _pickedImage!,
                                    previewBytes: _previewBytes,
                                  ),
                                  Positioned(
                                    left: 8,
                                    top: 8,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: _showChangePhotoSheet,
                                      child: const Text(
                                        'Fotoğraf Değiştir',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (!_hasPhoto) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_rounded, size: 22),
                        label: const Text(
                          'Fotoğraf çek',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon:
                            const Icon(Icons.photo_library_rounded, size: 22),
                        label: const Text(
                          'Galeriden seç',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_hasPhoto) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Balık türü (isteğe bağlı)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kCommonFishSpecies
                          .map(
                            (species) => FilterChip(
                              label: Text(species),
                              selected: _selectedFish.contains(species),
                              onSelected: (_) => _toggleFish(species),
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.28),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _selectedFish.contains(species)
                                    ? AppColors.foam
                                    : AppColors.foam.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fishExtraController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Başka tür (virgülle yazabilirsin)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _captionController,
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ne düşünüyorsun?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_showPrivateSpotNotice)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  AppColors.warning.withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Gizli merada gönderide yalnızca bölge '
                                  'bilgisi görünür.',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Text(
                      'Mera (isteğe bağlı)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_loadingSpots)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (_userSpots.isEmpty && _spotsLoaded)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Kayıtlı meran yok. İstersen boş bırak.',
                          style: TextStyle(
                            color: AppColors.muted.withValues(alpha: 0.95),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      InputDecorator(
                        decoration: const InputDecoration(
                          hintText: 'İstersen mera bağla',
                          isDense: true,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _effectiveSpotIdForDropdown,
                            isExpanded: true,
                            isDense: true,
                            hint: Text(
                              'Mera seç',
                              style: TextStyle(
                                color:
                                    AppColors.muted.withValues(alpha: 0.9),
                                fontSize: 15,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Mera gösterme'),
                              ),
                              ..._userSpots.map(
                                (spot) => DropdownMenuItem<String?>(
                                  value: spot.id,
                                  child: Text(
                                    '${spot.name} · '
                                    '${_privacyLabel(spot.privacyLevel)}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _selectedSpotId = v;
                            }),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (_hasPhoto)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.foam,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _uploading ? null : _share,
                    child: _uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.foam,
                            ),
                          )
                        : const Text(
                            'PAYLAŞ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _privacyLabel(String level) => switch (level) {
        'private' => 'Gizli',
        'vip' => 'VIP',
        'friends' => 'Arkadaşlar',
        _ => 'Herkese açık',
      };
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 56,
          color: AppColors.muted.withValues(alpha: 0.85),
        ),
        const SizedBox(height: 12),
        Text(
          'Kamera veya galeri',
          style: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.95),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Aşağıdan seç',
          style: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.75),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final XFile pickedImage;
  final Uint8List? previewBytes;

  const _PhotoPreview({
    required this.pickedImage,
    this.previewBytes,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && previewBytes != null) {
      return Image.memory(
        previewBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    return Image.file(
      File(pickedImage.path),
      fit: BoxFit.cover,
      width: double.infinity,
    );
  }
}
