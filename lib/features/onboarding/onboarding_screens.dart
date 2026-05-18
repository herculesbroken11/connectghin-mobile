import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../../core/widgets/cg_text_field.dart';
import '../profiles/data/profiles_api.dart';
import '../verification/data/verification_api.dart';

class _AddressSuggestion {
  const _AddressSuggestion({required this.placeId, required this.description});
  final String placeId;
  final String description;
}

class _ResolvedPlace {
  const _ResolvedPlace({
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    required this.locationLat,
    required this.locationLng,
  });

  final String addressLine1;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final double? locationLat;
  final double? locationLng;
}

List<Map<String, dynamic>> _sortedPhotosFromUser(Map<String, dynamic>? user) {
  final raw = user?['profilePhotos'] as List<dynamic>? ?? [];
  final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  list.sort((a, b) => (a['sortOrder'] as int? ?? 0).compareTo(b['sortOrder'] as int? ?? 0));
  return list;
}

// --- Step 1: Basic info ---

class OnboardingBasicScreen extends StatefulWidget {
  const OnboardingBasicScreen({super.key});

  @override
  State<OnboardingBasicScreen> createState() => _OnboardingBasicScreenState();
}

class _OnboardingBasicScreenState extends State<OnboardingBasicScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();
  final _country = TextEditingController();
  final _bio = TextEditingController();
  String? _gender;
  bool _saving = false;
  Timer? _addressDebounce;
  bool _searchingAddress = false;
  bool _suppressAddressSearch = false;
  List<_AddressSuggestion> _addressSuggestions = const [];
  double? _locationLat;
  double? _locationLng;

  static const _genders = ['Woman', 'Man', 'Non-binary', 'Prefer not to say'];

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _postalCode.dispose();
    _country.dispose();
    _bio.dispose();
    _addressDebounce?.cancel();
    super.dispose();
  }

  String? get _placesApiKey {
    const fromDefine = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
    final key = fromDefine.trim();
    return key.isEmpty ? null : key;
  }

  Future<void> _onAddressChanged(String value) async {
    if (_suppressAddressSearch) return;
    // If user edits the address after choosing a Google suggestion, drop coordinates.
    _locationLat = null;
    _locationLng = null;
    final q = value.trim();
    _addressDebounce?.cancel();
    if (q.length < 3) {
      if (!mounted) return;
      setState(() {
        _searchingAddress = false;
        _addressSuggestions = const [];
      });
      return;
    }
    _addressDebounce = Timer(const Duration(milliseconds: 320), () async {
      final key = _placesApiKey;
      if (key == null) return;
      if (!mounted) return;
      setState(() => _searchingAddress = true);
      try {
        final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
          'input': q,
          'key': key,
          'types': 'address',
          'language': 'en',
        });
        final res = await http.get(uri);
        if (res.statusCode != 200) throw Exception('Autocomplete failed (${res.statusCode})');
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final preds = (json['predictions'] as List<dynamic>? ?? const <dynamic>[]);
        final items = preds
            .map((e) => e as Map<String, dynamic>)
            .map(
              (e) => _AddressSuggestion(
                placeId: e['place_id'] as String? ?? '',
                description: e['description'] as String? ?? '',
              ),
            )
            .where((e) => e.placeId.isNotEmpty && e.description.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _addressSuggestions = items.take(6).toList();
          _searchingAddress = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _addressSuggestions = const [];
          _searchingAddress = false;
        });
      }
    });
  }

  Future<void> _selectSuggestion(_AddressSuggestion s) async {
    final key = _placesApiKey;
    if (key == null) return;
    setState(() => _searchingAddress = true);
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': s.placeId,
        'key': key,
        'fields': 'address_component,formatted_address,geometry',
      });
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('Place details failed (${res.statusCode})');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final result = json['result'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final resolved = _resolvePlace(result);
      _suppressAddressSearch = true;
      _address.text = resolved.addressLine1.isNotEmpty ? resolved.addressLine1 : s.description;
      _city.text = resolved.city;
      _state.text = resolved.state;
      _postalCode.text = resolved.postalCode;
      _country.text = resolved.country;
      _locationLat = resolved.locationLat;
      _locationLng = resolved.locationLng;
      _suppressAddressSearch = false;
      if (!mounted) return;
      setState(() {
        _searchingAddress = false;
        _addressSuggestions = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchingAddress = false);
      showApiErrorSnackBar(context, e);
    }
  }

  _ResolvedPlace _resolvePlace(Map<String, dynamic> result) {
    String streetNumber = '';
    String route = '';
    String locality = '';
    String adminArea = '';
    String postalCode = '';
    String country = '';
    final comps = result['address_components'] as List<dynamic>? ?? const <dynamic>[];
    for (final raw in comps) {
      final c = raw as Map<String, dynamic>;
      final types = (c['types'] as List<dynamic>? ?? const <dynamic>[]).cast<String>();
      final longName = c['long_name'] as String? ?? '';
      final shortName = c['short_name'] as String? ?? '';
      if (types.contains('street_number')) streetNumber = longName;
      if (types.contains('route')) route = longName;
      if (types.contains('locality')) locality = longName;
      if (types.contains('administrative_area_level_1')) adminArea = shortName.isNotEmpty ? shortName : longName;
      if (types.contains('postal_code')) postalCode = longName;
      if (types.contains('country')) country = longName;
      if (locality.isEmpty && types.contains('postal_town')) locality = longName;
      if (locality.isEmpty && types.contains('administrative_area_level_2')) locality = longName;
    }
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    final line1 = [streetNumber, route].where((e) => e.trim().isNotEmpty).join(' ').trim();
    return _ResolvedPlace(
      addressLine1: line1,
      city: locality,
      state: adminArea,
      postalCode: postalCode,
      country: country,
      locationLat: lat,
      locationLng: lng,
    );
  }

  Future<void> _continue() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a display name')));
      return;
    }
    final age = int.tryParse(_age.text.trim());
    if (age == null || age < 18 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid age (18–120)')));
      return;
    }
    if (_address.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _state.text.trim().isEmpty ||
        _postalCode.text.trim().isEmpty ||
        _country.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in address, city, state, zipcode, and country')),
      );
      return;
    }
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final bio = _bio.text.trim();
      final address = _address.text.trim();
      final city = _city.text.trim();
      final state = _state.text.trim();
      final postalCode = _postalCode.text.trim();
      final country = _country.text.trim();
      final body = <String, dynamic>{
        'displayName': name,
        'age': age,
        if (address.isNotEmpty) 'addressLine1': address,
        if (city.isNotEmpty) 'city': city,
        if (state.isNotEmpty) 'state': state,
        if (postalCode.isNotEmpty) 'postalCode': postalCode,
        if (country.isNotEmpty) 'country': country,
        if (_locationLat != null) 'locationLat': _locationLat,
        if (_locationLng != null) 'locationLng': _locationLng,
        if (bio.isNotEmpty) 'bio': bio,
        if (_gender != null && _gender!.isNotEmpty) 'gender': _gender,
      };
      await ProfilesApi(session.apiClient).updateMe(accessToken: t, body: body);
      session.bumpProfileRefresh();
      if (mounted) context.push(AppPaths.onboardingGolf);
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      stepIndex: 1,
      title: 'Basic info',
      subtitle: 'Tell us about yourself',
      isBusy: _saving,
      onNext: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CgLabeledField(
            label: 'Display Name',
            child: CgTextField(controller: _name, hint: "How you'd like to be called"),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CgLabeledField(
                  label: 'Age',
                  child: CgTextField(
                    controller: _age,
                    hint: '25',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _OnboardingDropdownField(
                  label: 'Gender',
                  hint: 'Select',
                  value: _gender,
                  items: _genders,
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CgLabeledField(
            label: 'Address',
            child: CgTextField(
              controller: _address,
              hint: 'Street address (type manually, or use suggestions if configured)',
              onChanged: _onAddressChanged,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _placesApiKey == null
                ? 'Optional: add GOOGLE_PLACES_API_KEY in .env for address suggestions as you type. You can enter your full address manually below.'
                : 'Suggestions appear as you type. You can still edit every field manually.',
            style: const TextStyle(fontSize: 12, color: CgColors.gray600, height: 1.35),
          ),
          if (_searchingAddress) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2, color: CgColors.green700),
          ],
          if (_addressSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: CgColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CgColors.gray200),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _addressSuggestions.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, color: CgColors.gray100),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, color: CgColors.gray500),
                      title: Text(_addressSuggestions[i].description, style: const TextStyle(fontSize: 14)),
                      onTap: () => _selectSuggestion(_addressSuggestions[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CgLabeledField(
                  label: 'City',
                  child: CgTextField(controller: _city, hint: 'San Francisco'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CgLabeledField(
                  label: 'State',
                  child: CgTextField(controller: _state, hint: 'CA'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CgLabeledField(
                  label: 'Zipcode',
                  child: CgTextField(controller: _postalCode, hint: '94105'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CgLabeledField(
                  label: 'Country',
                  child: CgTextField(controller: _country, hint: 'United States'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CgLabeledField(
            label: 'Bio',
            trailing: const Text(
              'Max 200 characters',
              style: TextStyle(fontSize: 12, color: CgColors.gray500),
            ),
            child: CgTextField(
              controller: _bio,
              hint: 'Tell us a bit about yourself and what you\'re looking for in a golf partner…',
              maxLines: 4,
              maxLength: 200,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Step 2: Golf info ---

class OnboardingGolfScreen extends StatefulWidget {
  const OnboardingGolfScreen({super.key});

  @override
  State<OnboardingGolfScreen> createState() => _OnboardingGolfScreenState();
}

class _OnboardingGolfScreenState extends State<OnboardingGolfScreen> {
  final _handicap = TextEditingController();
  final _ghin = TextEditingController();
  final _homeCourse = TextEditingController();
  String? _skillLevel;
  String? _playFrequency;
  bool _saving = false;

  static const _skillLevels = ['Beginner', 'Intermediate', 'Advanced', 'Professional'];
  static const _frequencies = ['Multiple times per week', 'Weekly', 'Monthly', 'A few times a year', 'Rarely'];

  @override
  void dispose() {
    _handicap.dispose();
    _ghin.dispose();
    _homeCourse.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final h = double.tryParse(_handicap.text.trim());
      final body = <String, dynamic>{
        if (h != null) 'handicap': h,
        if (_homeCourse.text.trim().isNotEmpty) 'homeCourse': _homeCourse.text.trim(),
        if (_skillLevel != null && _skillLevel!.isNotEmpty) 'skillLevel': _skillLevel,
        if (_playFrequency != null && _playFrequency!.isNotEmpty) 'playFrequency': _playFrequency,
      };
      if (body.isNotEmpty) {
        await ProfilesApi(session.apiClient).updateMe(accessToken: t, body: body);
        session.bumpProfileRefresh();
      }
      final ghin = _ghin.text.trim();
      if (ghin.isNotEmpty) {
        try {
          await VerificationApi(session.apiClient).submitRequest(accessToken: t, ghinNumber: ghin);
        } catch (e) {
          if (mounted) {
            showApiErrorSnackBar(context, e, prefix: 'Couldn\'t submit GHIN verification. ');
          }
        }
      }
      if (mounted) context.push(AppPaths.onboardingPreferences);
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      stepIndex: 2,
      title: 'Golf info',
      subtitle: 'Share your golf details',
      isBusy: _saving,
      onNext: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CgLabeledField(
            label: 'Handicap Index',
            child: CgTextField(
              controller: _handicap,
              hint: 'e.g., 12.5',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(height: 20),
          CgLabeledField(
            label: 'GHIN Number (Optional)',
            child: CgTextField(controller: _ghin, hint: 'Enter your GHIN number', keyboardType: TextInputType.text),
          ),
          const SizedBox(height: 6),
          const Text(
            'Verify your handicap to earn a trusted badge',
            style: TextStyle(fontSize: 13, color: CgColors.gray500),
          ),
          const SizedBox(height: 20),
          CgLabeledField(
            label: 'Home Course',
            child: CgTextField(controller: _homeCourse, hint: 'e.g., Pebble Beach Golf Links'),
          ),
          const SizedBox(height: 20),
          _OnboardingDropdownField(
            label: 'Skill Level',
            hint: 'Select your skill level',
            value: _skillLevel,
            items: _skillLevels,
            onChanged: (v) => setState(() => _skillLevel = v),
          ),
          const SizedBox(height: 20),
          _OnboardingDropdownField(
            label: 'How often do you play?',
            hint: 'Select frequency',
            value: _playFrequency,
            items: _frequencies,
            onChanged: (v) => setState(() => _playFrequency = v),
          ),
        ],
      ),
    );
  }
}

// --- Step 3: Preferences ---

class OnboardingPreferencesScreen extends StatefulWidget {
  const OnboardingPreferencesScreen({super.key});

  @override
  State<OnboardingPreferencesScreen> createState() => _OnboardingPreferencesScreenState();
}

class _OnboardingPreferencesScreenState extends State<OnboardingPreferencesScreen> {
  String? _pace;
  String? _competition;
  String? _drinking;
  String? _smoking;
  String? _music;
  bool _saving = false;

  static const _paceOptions = ['Relaxed', 'Moderate', 'Fast'];
  static const _competitionOptions = ['Casual', 'Friendly', 'Competitive'];
  static const _drinkingOptions = ['Yes', 'Sometimes', 'No', 'Prefer not to say'];
  static const _smokingOptions = ['Yes', 'Sometimes', 'No', 'Prefer not to say'];
  static const _musicOptions = ['Love it on the course', 'Sometimes', 'Prefer quiet golf'];

  Future<void> _continue() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final parts = <String>[];
      if (_pace != null && _pace!.isNotEmpty) {
        parts.add('Pace: ${_pace!}');
      }
      if (_competition != null && _competition!.isNotEmpty) {
        parts.add('Competition: ${_competition!}');
      }
      final body = <String, dynamic>{
        if (parts.isNotEmpty) 'lookingFor': parts.join('; '),
        if (_drinking != null && _drinking!.isNotEmpty) 'drinkingPreference': _drinking,
        if (_smoking != null && _smoking!.isNotEmpty) 'smokingPreference': _smoking,
        if (_music != null && _music!.isNotEmpty) 'musicPreference': _music,
      };
      if (body.isNotEmpty) {
        await ProfilesApi(session.apiClient).updateMe(accessToken: t, body: body);
        session.bumpProfileRefresh();
      }
      if (mounted) context.push(AppPaths.onboardingPhotos);
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      stepIndex: 3,
      title: 'Preferences',
      subtitle: 'Help us find compatible partners',
      isBusy: _saving,
      onNext: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OnboardingDropdownField(
            label: 'Pace of Play',
            hint: 'Select preferred pace',
            value: _pace,
            items: _paceOptions,
            onChanged: (v) => setState(() => _pace = v),
          ),
          const SizedBox(height: 20),
          _OnboardingDropdownField(
            label: 'Competition Level',
            hint: 'How competitive?',
            value: _competition,
            items: _competitionOptions,
            onChanged: (v) => setState(() => _competition = v),
          ),
          const SizedBox(height: 20),
          _OnboardingDropdownField(
            label: 'Drinking',
            hint: 'Select preference',
            value: _drinking,
            items: _drinkingOptions,
            onChanged: (v) => setState(() => _drinking = v),
          ),
          const SizedBox(height: 20),
          _OnboardingDropdownField(
            label: 'Smoking',
            hint: 'Select preference',
            value: _smoking,
            items: _smokingOptions,
            onChanged: (v) => setState(() => _smoking = v),
          ),
          const SizedBox(height: 20),
          _OnboardingDropdownField(
            label: 'Music on Course',
            hint: 'Select preference',
            value: _music,
            items: _musicOptions,
            onChanged: (v) => setState(() => _music = v),
          ),
        ],
      ),
    );
  }
}

// --- Step 4: Photos ---

class OnboardingPhotosScreen extends StatefulWidget {
  const OnboardingPhotosScreen({super.key});

  @override
  State<OnboardingPhotosScreen> createState() => _OnboardingPhotosScreenState();
}

class _OnboardingPhotosScreenState extends State<OnboardingPhotosScreen> {
  final _picker = ImagePicker();
  bool _uploading = false;
  bool _loading = true;
  List<Map<String, dynamic>> _photos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final me = await ProfilesApi(session.apiClient).getMe(t);
      final user = me['user'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _photos = _sortedPhotosFromUser(user);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      await ProfilesApi(session.apiClient).uploadPhotoFile(accessToken: t, filePath: img.path);
      session.bumpProfileRefresh();
      await _reload();
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteAt(int index) async {
    if (index < 0 || index >= _photos.length) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final id = _photos[index]['id'] as String?;
    if (id == null) return;
    await ProfilesApi(session.apiClient).deletePhoto(accessToken: t, photoId: id);
    session.bumpProfileRefresh();
    await _reload();
  }

  void _completeSetup() {
    if (_photos.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 photos to complete setup, or skip for now.')),
      );
      return;
    }
    context.go(AppPaths.app);
  }

  void _skip() {
    context.go(AppPaths.app);
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      stepIndex: 4,
      title: 'Add photos',
      subtitle: 'Add at least 2 photos to continue',
      isBusy: _uploading,
      nextLabel: 'Complete Setup',
      onNext: _completeSetup,
      primaryEnabled: !_uploading && !_loading,
      footerBelowButton: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: CgColors.gray700,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: _loading || _uploading ? null : _skip,
        child: const Text('Skip for now'),
      ),
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: CgColors.green700)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PhotoGrid(
                  photos: _photos,
                  uploading: _uploading,
                  onAddTap: _pickAndUpload,
                  onRemove: _deleteAt,
                ),
                const SizedBox(height: 20),
                _PhotoTipsCard(),
              ],
            ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.uploading,
    required this.onAddTap,
    required this.onRemove,
  });

  final List<Map<String, dynamic>> photos;
  final bool uploading;
  final VoidCallback onAddTap;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    const topHeight = 168.0;
    const smallH = (topHeight - gap) / 2;

    Map<String, dynamic>? at(int i) => i < photos.length ? photos[i] : null;

    return Column(
      children: [
        SizedBox(
          height: topHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _PhotoCell(
                  label: 'Photo 1',
                  imageUrl: at(0)?['imageUrl'] as String?,
                  isMain: true,
                  showRemove: at(0) != null,
                  busy: uploading,
                  onTap: onAddTap,
                  onRemove: at(0) != null ? () => onRemove(0) : null,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _PhotoCell(
                        label: 'Photo 2',
                        imageUrl: at(1)?['imageUrl'] as String?,
                        showRemove: at(1) != null,
                        busy: uploading,
                        onTap: onAddTap,
                        onRemove: at(1) != null ? () => onRemove(1) : null,
                      ),
                    ),
                    const SizedBox(height: gap),
                    Expanded(
                      child: _PhotoCell(
                        label: '',
                        imageUrl: at(2)?['imageUrl'] as String?,
                        showRemove: at(2) != null,
                        busy: uploading,
                        onTap: onAddTap,
                        onRemove: at(2) != null ? () => onRemove(2) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: gap),
        SizedBox(
          height: smallH,
          child: Row(
            children: [
              Expanded(child: _PhotoCell(imageUrl: at(3)?['imageUrl'] as String?, showRemove: at(3) != null, busy: uploading, onTap: onAddTap, onRemove: at(3) != null ? () => onRemove(3) : null)),
              const SizedBox(width: gap),
              Expanded(child: _PhotoCell(imageUrl: at(4)?['imageUrl'] as String?, showRemove: at(4) != null, busy: uploading, onTap: onAddTap, onRemove: at(4) != null ? () => onRemove(4) : null)),
              const SizedBox(width: gap),
              Expanded(child: _PhotoCell(imageUrl: at(5)?['imageUrl'] as String?, showRemove: at(5) != null, busy: uploading, onTap: onAddTap, onRemove: at(5) != null ? () => onRemove(5) : null)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.onTap,
    this.label = '',
    this.imageUrl,
    this.isMain = false,
    this.showRemove = false,
    this.busy = false,
    this.onRemove,
  });

  final String label;
  final String? imageUrl;
  final bool isMain;
  final bool showRemove;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: CgColors.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CgColors.gray300, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
              else
                CustomPaint(
                  painter: _DashedBorderPainter(color: CgColors.gray300),
                  child: Center(
                    child: busy
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: CgColors.green700))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 28, color: CgColors.gray400),
                              if (label.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(label, style: const TextStyle(color: CgColors.gray500, fontSize: 13)),
                              ],
                            ],
                          ),
                  ),
                ),
              if (isMain && hasImage)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: CgColors.green700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (showRemove && hasImage)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final next = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PhotoTipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CgColors.blue50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: CgColors.blue700),
              SizedBox(width: 8),
              Text('Photo Tips', style: TextStyle(fontWeight: FontWeight.w600, color: CgColors.blue700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          _tip('Use clear, recent photos of yourself'),
          _tip('Include photos on the golf course'),
          _tip('Avoid group photos as your main image'),
        ],
      ),
    );
  }

  static Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: CgColors.gray700, height: 1.35)),
          Expanded(child: Text(text, style: const TextStyle(color: CgColors.gray700, height: 1.35, fontSize: 14))),
        ],
      ),
    );
  }
}

// --- Shared scaffold & dropdown ---

/// Figma-style tracker: four discrete segments; completed steps fill left-to-right in green.
class _OnboardingSegmentedProgress extends StatelessWidget {
  const _OnboardingSegmentedProgress({required this.stepIndex});

  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final done = i < stepIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: 8,
              decoration: BoxDecoration(
                color: done ? CgColors.green700 : CgColors.gray200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.stepIndex,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onNext,
    this.nextLabel = 'Continue',
    this.isBusy = false,
    this.primaryEnabled = true,
    this.footerBelowButton,
  });

  final int stepIndex;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;
  final bool isBusy;
  final bool primaryEnabled;
  final Widget? footerBelowButton;

  @override
  Widget build(BuildContext context) {
    final busy = isBusy;
    return Scaffold(
      backgroundColor: CgColors.white,
      appBar: AppBar(
        backgroundColor: CgColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray900),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                'Step $stepIndex of 4',
                style: const TextStyle(fontSize: 14, color: CgColors.gray600, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: _OnboardingSegmentedProgress(stepIndex: stepIndex),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: CgResponsiveContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.6,
                        color: CgColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: CgColors.gray600,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(child: SingleChildScrollView(child: child)),
                    const SizedBox(height: 8),
                    CgPrimaryButton(
                      label: busy ? 'Saving…' : nextLabel,
                      onPressed: (busy || !primaryEnabled) ? null : onNext,
                      borderRadius: 12,
                      minHeight: 52,
                    ),
                    if (footerBelowButton != null) ...[
                      const SizedBox(height: 12),
                      Center(child: footerBelowButton!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingDropdownField extends StatelessWidget {
  const _OnboardingDropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = value != null && items.contains(value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: CgColors.gray900),
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: CgColors.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              hint: Text(hint, style: const TextStyle(color: CgColors.gray400, fontSize: 16)),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: CgColors.gray600),
              borderRadius: BorderRadius.circular(12),
              dropdownColor: CgColors.white,
              style: const TextStyle(fontSize: 16, color: CgColors.gray900),
              items: items
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
