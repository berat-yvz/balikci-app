import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/avatar_image_prepare.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';

/// Oturumdaki kullanıcı için profil düzenleme (kullanıcı adı, biyografi, avatar).
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Profili Düzenle'),
            ),
            body: const Center(
              child: Text(
                'Profil yüklenemedi.',
                style: TextStyle(color: AppColors.foam),
              ),
            ),
          );
        }
        return _EditProfileBody(user: user);
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Profili Düzenle'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (Object error, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Profili Düzenle'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.foam),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileBody extends ConsumerStatefulWidget {
  final UserModel user;

  const _EditProfileBody({required this.user});

  @override
  ConsumerState<_EditProfileBody> createState() => _EditProfileBodyState();
}

class _EditProfileBodyState extends ConsumerState<_EditProfileBody> {
  final _imagePicker = ImagePicker();
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
  }

  @override
  void didUpdateWidget(covariant _EditProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _usernameController.text = widget.user.username;
      _bioController.text = widget.user.bio ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _publicAvatarUrl(String avatarUrlOrPath) {
    if (avatarUrlOrPath.startsWith('http')) return avatarUrlOrPath;
    final base = dotenv.env['SUPABASE_URL'] ?? '';
    if (base.isEmpty) return avatarUrlOrPath;
    final b = avatarStorageBucket();
    return '$base/storage/v1/object/public/$b/$avatarUrlOrPath';
  }

  String _initials(String username) {
    final parts = username.trim().split(RegExp(r'\s+'));
    final a = parts.isNotEmpty ? parts.first[0] : 'U';
    final b = parts.length > 1
        ? parts.last[0]
        : (username.isNotEmpty ? username[0] : 'U');
    return (a + b).toUpperCase();
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      final picked =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await prepareAvatarUploadBytes(picked);
      final storagePath =
          'avatars/${widget.user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final bucket = avatarStorageBucket();
      await SupabaseService.storage.from(bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final repo = ref.read(userRepositoryProvider);
      await repo.updateProfile(
        userId: widget.user.id,
        avatarUrl: storagePath,
      );

      ref.invalidate(currentUserProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar güncellendi ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avatar yüklenemedi: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final trimmed = _usernameController.text.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı adı boş olamaz.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final bioRaw = _bioController.text.trim();
    final bioValue = bioRaw.isEmpty ? null : bioRaw;

    setState(() => _saving = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      await repo.updateProfile(
        userId: widget.user.id,
        username: trimmed,
        bio: bioValue,
        includeBioInUpdate: true,
      );

      ref.invalidate(currentUserProfileProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Güncelleme başarısız, tekrar dene'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.muted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initials = _initials(user.username);
    final authUser = ref.watch(currentUserProvider);
    if (authUser == null || authUser.id != user.id) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Profili Düzenle')),
        body: const Center(
          child: Text(
            'Oturum geçersiz.',
            style: TextStyle(color: AppColors.foam),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(_publicAvatarUrl(user.avatarUrl!))
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: AppColors.dark,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap:
                              _uploadingAvatar ? null : _pickAndUploadAvatar,
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(
                              child: _uploadingAvatar
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.foam,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 20,
                                      color: AppColors.foam,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 56,
              child: TextField(
                controller: _usernameController,
                style: const TextStyle(color: AppColors.foam),
                decoration: _fieldDecoration('Kullanıcı adı'),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              style: const TextStyle(color: AppColors.foam),
              decoration: _fieldDecoration(
                'Hakkında',
                hint: 'İsteğe bağlı',
              ),
              minLines: 3,
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.foam,
                        ),
                      )
                    : const Text('KAYDET'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
