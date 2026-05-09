import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/avatar_image_prepare.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';

/// Gönderi oluşturma — 3 adımlı PageView akışı.
///
/// Sayfa 1: Fotoğraf seç
/// Sayfa 2: Mera seç (opsiyonel)
/// Sayfa 3: Balık türü + caption + paylaş
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _pageController = PageController();
  final _captionController = TextEditingController();
  final _spotRepo = SpotRepository();

  XFile? _pickedImage;
  Uint8List? _previewBytes;

  SpotModel? _selectedSpot; // null = "Mera seçme"
  final Set<String> _selectedSpecies = {};

  List<SpotModel> _userSpots = [];
  bool _loadingSpots = false;
  bool _uploading = false;
  int _currentPage = 0;

  static const _speciesList = [
    'Lüfer',
    'Çipura',
    'Levrek',
    'Hamsi',
    'İstavrit',
    'Palamut',
    'Kefal',
    'Barbun',
    'Saroz',
    'Kalamar',
    'Tekir',
    'Mezgit',
    'Çupra',
    'İskorpit',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  // ── Fotoğraf yükle ──────────────────────────────────────────────────────────

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

  Future<String> _uploadPhoto() async {
    final uid = SupabaseService.auth.currentUser?.id ?? 'unknown';
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

  // ── Meralar ─────────────────────────────────────────────────────────────────

  Future<void> _loadSpots() async {
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _loadingSpots = true);
    try {
      final spots = await _spotRepo.getSpotsByUserId(uid);
      if (mounted) setState(() => _userSpots = spots);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSpots = false);
    }
  }

  // ── Navigasyon ──────────────────────────────────────────────────────────────

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = page);
  }

  void _nextPage() {
    if (_currentPage == 0 && _pickedImage == null) return;
    // Sayfa 1'e geçerken meraları yükle (sayfa 1'den çıkarken değil)
    if (_currentPage == 0) _loadSpots();
    _goToPage(_currentPage + 1);
  }

  void _prevPage() {
    if (_currentPage == 0) {
      Navigator.of(context).pop();
      return;
    }
    _goToPage(_currentPage - 1);
  }

  // ── Paylaş ──────────────────────────────────────────────────────────────────

  Future<void> _share() async {
    if (_pickedImage == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final photoUrl = await _uploadPhoto();
      await ref.read(postRepositoryProvider).createPost(
            photoUrl: photoUrl,
            caption: _captionController.text.trim().isEmpty
                ? null
                : _captionController.text.trim(),
            fishSpecies:
                _selectedSpecies.isEmpty ? null : _selectedSpecies.toList(),
            spotId: _selectedSpot?.id,
            spotDistrict: _selectedSpot?.description,
          );
      ref.invalidate(friendsFeedProvider);
      ref.invalidate(globalFeedProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gönderin paylaşıldı! 🎣'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gönderi paylaşılamadı: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _prevPage,
          tooltip: 'Geri',
        ),
        title: Text(_pageTitles[_currentPage]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: AppColors.surface,
            color: AppColors.primary,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _Page1Photo(
            pickedImage: _pickedImage,
            previewBytes: _previewBytes,
            onPick: _pickImage,
            onNext: _pickedImage != null ? _nextPage : null,
          ),
          _Page2Spot(
            userSpots: _userSpots,
            selectedSpot: _selectedSpot,
            loading: _loadingSpots,
            onSpotSelected: (spot) => setState(() => _selectedSpot = spot),
            onNext: _nextPage,
            onPrev: _prevPage,
          ),
          _Page3Details(
            speciesList: _speciesList,
            selectedSpecies: _selectedSpecies,
            captionController: _captionController,
            uploading: _uploading,
            selectedSpot: _selectedSpot,
            onSpeciesToggle: (s) => setState(
              () => _selectedSpecies.contains(s)
                  ? _selectedSpecies.remove(s)
                  : _selectedSpecies.add(s),
            ),
            onShare: _share,
            onPrev: _prevPage,
          ),
        ],
      ),
    );
  }

  static const _pageTitles = [
    'Fotoğraf Seç',
    'Mera Seç',
    'Detaylar',
  ];
}

// ── Sayfa 1: Fotoğraf ────────────────────────────────────────────────────────

class _Page1Photo extends StatelessWidget {
  final XFile? pickedImage;
  final Uint8List? previewBytes;
  final VoidCallback onPick;
  final VoidCallback? onNext;

  const _Page1Photo({
    required this.pickedImage,
    this.previewBytes,
    required this.onPick,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Fotoğraf alanı
          GestureDetector(
            onTap: onPick,
            child: Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.muted.withValues(alpha: 0.4),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: pickedImage == null
                  ? const _PhotoPlaceholder()
                  : _PhotoPreview(
                      pickedImage: pickedImage!,
                      previewBytes: previewBytes,
                    ),
            ),
          ),
          const SizedBox(height: 20),
          // Galeri butonu
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('📷 Galeriden Seç'),
            ),
          ),
          const SizedBox(height: 16),
          // İleri
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    onNext != null ? AppColors.primary : AppColors.muted,
              ),
              child: const Text('İleri →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.add_photo_alternate_outlined,
          size: 64,
          color: AppColors.muted,
        ),
        const SizedBox(height: 12),
        Text(
          'Fotoğraf seçmek için dokun',
          style: TextStyle(color: AppColors.muted, fontSize: 16),
        ),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final XFile pickedImage;
  final Uint8List? previewBytes;

  const _PhotoPreview({required this.pickedImage, this.previewBytes});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && previewBytes != null) {
      return Image.memory(previewBytes!, fit: BoxFit.cover, width: double.infinity);
    }
    return Image.file(
      File(pickedImage.path),
      fit: BoxFit.cover,
      width: double.infinity,
    );
  }
}

// ── Sayfa 2: Mera ────────────────────────────────────────────────────────────

class _Page2Spot extends StatelessWidget {
  final List<SpotModel> userSpots;
  final SpotModel? selectedSpot;
  final bool loading;
  final ValueChanged<SpotModel?> onSpotSelected;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _Page2Spot({
    required this.userSpots,
    required this.selectedSpot,
    required this.loading,
    required this.onSpotSelected,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Nerede oltayı attın?',
            style: AppTextStyles.h2.copyWith(color: AppColors.foam),
          ),
        ),

        // Gizli mera uyarısı
        if (selectedSpot != null &&
            (selectedSpot!.privacyLevel == 'private' ||
                selectedSpot!.privacyLevel == 'vip'))
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bu mera gizli. Gönderide yalnızca ilçe adı görünecek, konumu kimse göremez.',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : userSpots.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Henüz mera eklemedin\n📍 Haritadan mera ekleyebilirsin',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: userSpots.length + 1,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            minTileHeight: 64,
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.muted.withValues(alpha: 0.25),
                              child: const Icon(
                                Icons.not_listed_location_outlined,
                                color: AppColors.muted,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'Mera seçme',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foam,
                              ),
                            ),
                            subtitle: const Text(
                              'Konumu paylaşma',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                            selected: selectedSpot == null,
                            selectedColor: AppColors.primary,
                            onTap: () => onSpotSelected(null),
                            trailing: selectedSpot == null
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  )
                                : null,
                          );
                        }
                        final spot = userSpots[index - 1];
                        final privColor = _privacyColor(spot.privacyLevel);
                        final privIcon = _privacyIcon(spot.privacyLevel);
                        final privLabel = _privacyLabel(spot.privacyLevel);
                        return ListTile(
                          minTileHeight: 64,
                          leading: CircleAvatar(
                            backgroundColor: privColor.withValues(alpha: 0.2),
                            child: Icon(privIcon, color: privColor, size: 20),
                          ),
                          title: Text(
                            spot.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foam,
                            ),
                          ),
                          subtitle: Text(
                            privLabel,
                            style: TextStyle(
                              color: privColor,
                              fontSize: 13,
                            ),
                          ),
                          selected: selectedSpot?.id == spot.id,
                          selectedColor: AppColors.primary,
                          onTap: () => onSpotSelected(spot),
                          trailing: selectedSpot?.id == spot.id
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                        );
                      },
                    ),
        ),

        // Navigasyon butonları
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: onPrev,
                    child: const Text('← Geri'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onNext,
                    child: const Text('İleri →'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _privacyIcon(String level) => switch (level) {
        'private' => Icons.lock_outline_rounded,
        'vip' => Icons.workspace_premium_rounded,
        'friends' => Icons.group_outlined,
        _ => Icons.place_outlined,
      };

  Color _privacyColor(String level) => switch (level) {
        'private' => AppColors.muted,
        'vip' => AppColors.accent,
        'friends' => AppColors.secondary,
        _ => AppColors.primary,
      };

  String _privacyLabel(String level) => switch (level) {
        'private' => 'Gizli',
        'vip' => 'VIP',
        'friends' => 'Arkadaşlar',
        _ => 'Herkese Açık',
      };
}

// ── Sayfa 3: Detaylar ────────────────────────────────────────────────────────

class _Page3Details extends StatelessWidget {
  final List<String> speciesList;
  final Set<String> selectedSpecies;
  final TextEditingController captionController;
  final bool uploading;
  final SpotModel? selectedSpot;
  final ValueChanged<String> onSpeciesToggle;
  final VoidCallback onShare;
  final VoidCallback onPrev;

  const _Page3Details({
    required this.speciesList,
    required this.selectedSpecies,
    required this.captionController,
    required this.uploading,
    required this.selectedSpot,
    required this.onSpeciesToggle,
    required this.onShare,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balık türleri
          Text(
            'Hangi balığı yakaladın?',
            style: AppTextStyles.h3.copyWith(color: AppColors.foam),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: speciesList.map((species) {
              final selected = selectedSpecies.contains(species);
              return SizedBox(
                height: 48,
                child: FilterChip(
                  label: Text(
                    species,
                    style: TextStyle(
                      fontSize: 15,
                      color: selected ? AppColors.foam : AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => onSpeciesToggle(species),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  checkmarkColor: AppColors.foam,
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : AppColors.muted.withValues(alpha: 0.3),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Caption
          Text(
            'Bir şeyler yaz (opsiyonel)',
            style: AppTextStyles.h3.copyWith(color: AppColors.foam),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: captionController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Ne yakaladın? Nasıl geçti?',
            ),
          ),
          const SizedBox(height: 24),

          // Butonlar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: uploading ? null : onPrev,
                    child: const Text('← Geri'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: uploading ? null : onShare,
                    child: uploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.foam,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('PAYLAŞ 🎣'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
