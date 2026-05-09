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

/// Gönderi oluşturma — tek kaydırmalı ekran, Facebook tarzı sade akış.
///
/// Fotoğraf + yazı zorunlu adım; mera ve balık etiketi isteğe bağlı (katlanır).
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _fishSpeciesController = TextEditingController();
  final _spotRepo = SpotRepository();

  XFile? _pickedImage;
  Uint8List? _previewBytes;

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
    _fishSpeciesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
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
      throw Exception('Oturum bulunamadı. Tekrar giriş yap.');
    }
    final path = '$uid/posts/${DateTime.now().millisecondsSinceEpoch}.webp';
    final bytes = await prepareAvatarUploadBytes(_pickedImage!);
    await SupabaseService.storage.from(AppConstants.photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/webp',
            upsert: true,
          ),
        );
    return SupabaseService.storage
        .from(AppConstants.photoBucket)
        .getPublicUrl(path);
  }

  List<String>? _parsedFishSpecies() {
    final raw = _fishSpeciesController.text.trim();
    if (raw.isEmpty) return null;
    final parts = raw
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts;
  }

  Future<void> _share() async {
    if (!_hasPhoto || _uploading) return;
    setState(() => _uploading = true);
    try {
      final photoUrl = await _uploadPhoto();
      final spot = _resolvedSpot();
      await ref.read(postRepositoryProvider).createPost(
            photoUrl: photoUrl,
            caption: _captionController.text.trim().isEmpty
                ? null
                : _captionController.text.trim(),
            fishSpecies: _parsedFishSpecies(),
            spotId: spot?.id,
            spotDistrict: spot?.description,
          );
      ref.invalidate(friendsFeedProvider);
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
      debugPrint('createPost: $e\n$st');
      if (!mounted) return;
      final friendly = ErrorMessageHelper.toUserMessage(
        e,
        fallback: 'Gönderi paylaşılamadı. Tekrar dene.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendly),
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
        title: Text(_hasPhoto ? 'Yeni gönderi' : 'Fotoğraf seç'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: AspectRatio(
                      aspectRatio: 1,
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
                            : _PhotoPreview(
                                pickedImage: _pickedImage!,
                                previewBytes: _previewBytes,
                              ),
                      ),
                    ),
                  ),
                  if (!_hasPhoto) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Galeriden seç'),
                      ),
                    ),
                  ],
                  if (_hasPhoto) ...[
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
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text(
                          'Konum veya balık (isteğe bağlı)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.foam,
                          ),
                        ),
                        subtitle: Text(
                          'Boş bırakabilirsin',
                          style: TextStyle(
                            color: AppColors.muted.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                        onExpansionChanged: (open) {
                          if (open) _loadSpotsIfNeeded();
                        },
                        children: [
                          if (_showPrivateSpotNotice)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.45),
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
                          TextField(
                            controller: _fishSpeciesController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText:
                                  'Balık türleri — virgülle: Lüfer, Çipura',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Mera',
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
                  height: 52,
                  child: ElevatedButton(
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
                            'Paylaş',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
          'Fotoğraf seç',
          style: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.95),
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
