import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/fish_log_provider.dart';

/// Günlük kayıt ekleme ekranı.
class AddLogScreen extends ConsumerStatefulWidget {
  final String? spotId;

  const AddLogScreen({super.key, this.spotId});

  @override
  ConsumerState<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends ConsumerState<AddLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _speciesController = TextEditingController();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isPrivate = false;
  bool _released = false;

  static const _suggestedSpecies = <String>[
    'Levrek',
    'Çipura',
    'Hamsi',
    'Lüfer',
    'Palamut',
    'Karagöz',
    'İstavrit',
    'Barbun',
    'Kefal',
    'Kalkan',
  ];

  @override
  void dispose() {
    _speciesController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(fishLogNotifierProvider.notifier);

    final species = _speciesController.text.trim();
    final weight =
        _weightController.text.trim().isEmpty ? null : double.tryParse(_weightController.text.trim());
    final length =
        _lengthController.text.trim().isEmpty ? null : double.tryParse(_lengthController.text.trim());
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    try {
      await notifier.addLog(
        spotId: widget.spotId,
        species: species,
        weightKg: weight,
        lengthCm: length,
        notes: notes,
        isPrivate: _isPrivate,
        released: _released,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Günlük kaydı eklendi ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Günlük kaydı eklenemedi: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(fishLogNotifierProvider);
    final isLoading = asyncState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Av Kaydı'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  '📸 Fotoğrafınız EXIF ile doğrulanacak. Konum ve tarih bilgisi puan hesabını etkiler.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.toLowerCase();
                    if (query.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _suggestedSpecies.where(
                      (s) => s.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (value) {
                    _speciesController.text = value;
                  },
                  fieldViewBuilder: (
                    context,
                    controller,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    controller.text = _speciesController.text;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                    _speciesController
                        .addListener(() => controller.text = _speciesController.text);
                    return TextFormField(
                      controller: _speciesController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Tür (Levrek, Çipura, Hamsi...)',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Lütfen balık türünü yaz.';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Ağırlık (kg)',
                    hintText: 'Örn: 1.2',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lengthController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Boy (cm)',
                    hintText: 'Örn: 35',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notlar (isteğe bağlı)',
                    hintText: 'Yem, takım, hava durumu notları...',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isPrivate,
                  onChanged: (v) {
                    setState(() => _isPrivate = v);
                  },
                  title: const Text('Gizli kayıt'),
                  subtitle: const Text(
                    'Gizli kayıtlar sadece senin profilinde görünür.',
                  ),
                ),
                SwitchListTile(
                  value: _released,
                  onChanged: (v) {
                    setState(() => _released = v);
                  },
                  title: const Text('Balığı geri saldım'),
                  subtitle: const Text(
                    'Sürdürülebilirlik puanını arttırır.',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kaydı Oluştur'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

