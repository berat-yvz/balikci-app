import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/score_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/auth_repository.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';

/// Mera ekleme / düzenleme formu — H4.
class AddSpotScreen extends StatefulWidget {
  /// Doluysa mevcut mera güncellenir (`updateSpot`).
  final SpotModel? spotToEdit;

  const AddSpotScreen({super.key, this.spotToEdit});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final SpotRepository _repo = SpotRepository();

  String _type = 'kıyı';
  String _privacy = 'public';
  double? _lat;
  double? _lng;
  bool _saving = false;

  static const _types = [
    ('kıyı', 'Kıyı'),
    ('kayalık', 'Kayalık'),
    ('iskele', 'İskele'),
    ('tekne', 'Tekne'),
    ('göl', 'Göl'),
    ('nehir', 'Nehir'),
  ];

  static const _privacyOptions = [
    ('public', 'Herkes', '+50 puan (public)', 'Konumun haritada herkese görünür.'),
    ('friends', 'Takipçiler', 'Arkadaş merası', 'Yalnızca arkadaşlık isteği kabul ettiğin kişiler görür.'),
    ('private', 'Sadece ben', 'Konum gizli', 'Sadece sen görürsün. Kimseyle paylaşılmaz.'),
    ('vip', 'VIP (Usta+)', 'Rütbe gerekebilir', 'Usta ve Deniz Reisi rütbesindeki balıkçılar görür.'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.spotToEdit;
    if (e != null) {
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description ?? '';
      _type = e.type ?? 'kıyı';
      _privacy = e.privacyLevel;
      _lat = e.lat;
      _lng = e.lng;

      final uid = SupabaseService.auth.currentUser?.id;
      if (uid != e.userId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bu merayı yalnızca ekleyen kullanıcı düzenleyebilir.',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
          context.pop();
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.spotToEdit != null;

  Future<void> _useGps() async {
    final pos = await LocationService.getCurrentPosition(
      purpose: LocationPurpose.spotAdd,
    );
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. İzin veya GPS açık mı kontrol edin.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
    });
  }

  Future<void> _pickOnMap() async {
    final initial = (_lat != null && _lng != null)
        ? LatLng(_lat!, _lng!)
        : null;
    final result = await context.push<LatLng>(
      '/map/pick-location',
      extra: initial,
    );
    if (!mounted || result == null) return;
    setState(() {
      _lat = result.latitude;
      _lng = result.longitude;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum gerekli'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum seçin (GPS veya harita)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = SupabaseService.auth.currentUser!;
      await AuthRepository().ensureUserProfile(user);
      if (_isEdit) {
        final spot = widget.spotToEdit!;
        if (spot.userId != uid) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bu merayı yalnızca ekleyen kullanıcı düzenleyebilir.',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
        final id = spot.id;
        await _repo.updateSpot(id, {
          'name': _nameCtrl.text.trim(),
          'lat': _lat,
          'lng': _lng,
          'type': _type,
          'privacy_level': _privacy,
          'description': _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        });
      } else {
        await _repo.addSpot({
          'user_id': uid,
          'name': _nameCtrl.text.trim(),
          'lat': _lat,
          'lng': _lng,
          'type': _type,
          'privacy_level': _privacy,
          'description': _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        });
      }
      // Yeni mera oluşturulduysa (güncelleme değil) puan ver
      if (!_isEdit && _privacy == 'public') {
        unawaited(ScoreService.award(uid, ScoreSource.spotPublic));
      }

      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Mera güncellendi' : 'Mera eklendi'),
          backgroundColor: AppColors.pinPublic,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt başarısız: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(_isEdit ? 'Mera Düzenle' : 'Mera Ekle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Mera Adı',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ad gerekli' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tür',
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  items: _types
                      .map(
                        (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Gizlilik',
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _privacy,
                  isExpanded: true,
                  items: _privacyOptions
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.$1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${e.$2} — ${e.$3}'),
                              Text(
                                e.$4,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                  color: e.$1 == 'private'
                                      ? AppColors.primary
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _privacy = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            _PrivacyInfoBanner(privacy: _privacy),
            const SizedBox(height: 16),
            const Text('Konum', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            if (_lat != null && _lng != null)
              Text(
                'Secili: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                style: AppTextStyles.caption,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _useGps,
                    icon: const Icon(Icons.my_location),
                    label: const Text('GPS'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickOnMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Haritada Seç'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gizlilik puan uyarısı (H13)
// ---------------------------------------------------------------------------

class _PrivacyInfoBanner extends StatelessWidget {
  final String privacy;
  const _PrivacyInfoBanner({required this.privacy});

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (privacy) {
      'public' => (
          Icons.emoji_events_outlined,
          'Public meranı herkesle paylaşıyorsun — +50 puan kazanırsın. 🎣',
          AppColors.success,
        ),
      'friends' => (
          Icons.people_outline,
          'Sadece takipçilerin görebilir — puan kazanmazsın ama gizliliğin korunur.',
          AppColors.secondary,
        ),
      'private' => (
          Icons.lock_outline,
          'Sadece sen görürsün — puan yok. Özel noktalarını saklamak için ideal.',
          AppColors.muted,
        ),
      'vip' => (
          Icons.star_outline,
          'Usta+ rütbesindekiler görebilir — puan yok. VIP takımın için harika.',
          AppColors.accent,
        ),
      _ => (Icons.info_outline, '', Colors.white54),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
