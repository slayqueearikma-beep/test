import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/data/city_coordinates.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';

class SellerProfileScreen extends ConsumerStatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  ConsumerState<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen> {
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  LatLng _location = CityCoordinates.casablanca;
  bool _isActive = true;
  bool _loading = false;
  bool _hydrated = false;
  String _coverUrl = '';
  String _logoUrl = '';
  XFile? _coverImage;
  XFile? _logoImage;

  final Map<String, bool> _openDays = {
    'Mon': true,
    'Tue': true,
    'Wed': true,
    'Thu': true,
    'Fri': true,
    'Sat': true,
    'Sun': false,
  };
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  void _hydrate(SellerModel seller, {required bool isActive}) {
    if (_hydrated) return;
    _businessNameController.text = seller.businessName;
    _descriptionController.text = seller.description;
    _addressController.text = seller.address;
    _phoneController.text = seller.phone;
    _location = LatLng(seller.latitude, seller.longitude);
    _coverUrl = seller.coverImageUrl;
    _logoUrl = seller.logoImageUrl;
    _isActive = isActive;
    final hours = seller.openingHours;
    if (!hours.isEmpty) {
      hours.days.forEach((key, value) {
        if (_openDays.containsKey(key)) _openDays[key] = value;
      });
      _openTime = _parseTime(hours.open, _openTime);
      _closeTime = _parseTime(hours.close, _closeTime);
    }
    _hydrated = true;
  }

  Future<void> _pick(void Function(XFile) setter) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (image != null) setState(() => setter(image));
  }

  Future<void> _pickTime({required bool open}) async {
    final initial = open ? _openTime : _closeTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (open) {
        _openTime = picked;
      } else {
        _closeTime = picked;
      }
    });
  }

  Future<String> _uploadOptional(XFile? file, String existing) async {
    if (file == null) return existing;
    return ref.read(uploadServiceProvider).uploadImage(file);
  }

  Future<void> _save(SellerModel seller) async {
    final l10n = context.l10n;
    if (_businessNameController.text.trim().length < 2 ||
        _addressController.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.completeRequiredStep)));
      return;
    }

    setState(() => _loading = true);
    try {
      await apiServiceProvider.runSubmit(() async {
        final cover = await _uploadOptional(_coverImage, _coverUrl);
        final logo = await _uploadOptional(_logoImage, _logoUrl);

        await apiServiceProvider.updateSeller(
          seller.id,
          SellerUpdatePayload(
            businessName: _businessNameController.text.trim(),
            description: _descriptionController.text.trim(),
            address: _addressController.text.trim(),
            city: AppConfig.launchCity,
            latitude: _location.latitude,
            longitude: _location.longitude,
            phone: _phoneController.text.trim(),
            coverImageUrl: cover,
            logoImageUrl: logo,
            isActive: _isActive,
            openingHours: {
              'days': Map<String, bool>.from(_openDays),
              'open': _formatTime(_openTime),
              'close': _formatTime(_closeTime),
            },
          ),
        );
      });

      ref.invalidate(sellerAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context, title: l10n.somethingWentWrong, message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(sellerAccountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileManagement)),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(sellerAccountProvider),
        ),
        data: (account) {
          _hydrate(account.profile, isActive: account.stats.isActive);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_isActive ? l10n.storeVisible : l10n.storeHidden),
                value: _isActive,
                onChanged: _loading ? null : (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _businessNameController,
                enabled: !_loading,
                decoration: InputDecoration(labelText: l10n.businessName),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descriptionController,
                enabled: !_loading,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.businessDescription),
              ),
              const SizedBox(height: AppSpacing.md),
              InputDecorator(
                decoration: InputDecoration(labelText: l10n.reviewCity),
                child: const Text(AppConfig.launchCity),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _addressController,
                enabled: !_loading,
                decoration: InputDecoration(labelText: l10n.fullAddress),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phoneController,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.phoneNumber),
              ),
              const SizedBox(height: AppSpacing.lg),
              StoreLocationPickerTile(
                location: _location,
                onLocationChanged: (latLng) => setState(() => _location = latLng),
                label: l10n.storeLocation,
                hint: l10n.tapMapToSetPin,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.openingHours, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _openDays.keys.map((day) {
                  final selected = _openDays[day] ?? false;
                  return FilterChip(
                    label: Text(l10n.dayLabel(day)),
                    selected: selected,
                    onSelected: _loading
                        ? null
                        : (value) => setState(() => _openDays[day] = value),
                  );
                }).toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _pickTime(open: true),
                      child: Text('${l10n.opens} ${_formatTime(_openTime)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _pickTime(open: false),
                      child: Text('${l10n.closes} ${_formatTime(_closeTime)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.businessLogo, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _ImageSlot(
                file: _logoImage,
                url: _logoUrl,
                onTap: () => _pick((f) => _logoImage = f),
                label: l10n.tapToUpload,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.coverPhoto, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _ImageSlot(
                file: _coverImage,
                url: _coverUrl,
                onTap: () => _pick((f) => _coverImage = f),
                label: l10n.tapToUpload,
                tall: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: l10n.saveChanges,
                onPressed: () => _save(account.profile),
                isLoading: _loading,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({
    required this.onTap,
    required this.label,
    this.file,
    this.url = '',
    this.tall = false,
  });

  final VoidCallback onTap;
  final String label;
  final XFile? file;
  final String url;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: tall ? 16 / 9 : 1.6,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: file != null
              ? Image.file(File(file!.path), fit: BoxFit.cover)
              : url.isNotEmpty
                  ? NetworkImageView(url: url, placeholderIcon: Icons.image_outlined)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined),
                        const SizedBox(height: 8),
                        Text(label),
                      ],
                    ),
        ),
      ),
    );
  }
}
