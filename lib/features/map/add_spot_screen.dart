import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/location_service.dart';
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
    ('public', 'Herkes', '+50 puan (public)'),
    ('friends', 'Takipçiler', 'Arkadaş merası'),
    ('private', 'Sadece ben', 'Konum gizli'),
    ('vip', 'VIP (Usta+)', 'Rütbe gerekebilir'),
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
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alinamadi. Izin veya GPS acik mi kontrol edin.'),
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
          content: Text('Konum secin (GPS veya harita)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = SupabaseService.auth.currentUser!;
      await AuthRepository().ensureUserProfile(user);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mera eklendi'),
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
      appBar: AppBar(title: const Text('Mera ekle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Mera adi',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ad gerekli' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Aciklama (istege bagli)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tur',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  items: _types
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.$1,
                          child: Text(e.$2),
                        ),
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
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _privacy,
                  isExpanded: true,
                  items: _privacyOptions
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.$1,
                          child: Text('${e.$2} — ${e.$3}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _privacy = v);
                  },
                ),
              ),
            ),
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
                    label: const Text('Haritada sec'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
