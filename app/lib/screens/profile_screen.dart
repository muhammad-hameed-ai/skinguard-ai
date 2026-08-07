// ═══════════════════════════════════════════════════════════════
//  Profile Screen (§3.11)
//
//  Photo, name, contact, address, age, Fitzpatrick skin type, notes.
//  Collect skin type because model performance varies across it.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _contact = '';
  String _address = '';
  int? _age;
  int? _fitzpatrick;
  String _notes = '';
  
  bool _loading = true;
  bool _saving = false;

  final _fitzpatrickOptions = {
    1: 'Type I (Always burns, never tans)',
    2: 'Type II (Usually burns, tans minimally)',
    3: 'Type III (Sometimes mild burn, tans uniformly)',
    4: 'Type IV (Burns minimally, always tans well)',
    5: 'Type V (Very rarely burns, tans very easily)',
    6: 'Type VI (Never burns)',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      // Guest mode
      setState(() => _loading = false);
      return;
    }

    final user = await DatabaseService.instance.getUserById(userId);
    if (user != null && mounted) {
      setState(() {
        _name = user['full_name'] as String? ?? '';
        _contact = user['contact'] as String? ?? '';
        _address = user['address'] as String? ?? '';
        _age = user['age'] as int?;
        _fitzpatrick = user['fitzpatrick'] as int?;
        _notes = user['notes'] as String? ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save profile in guest mode')),
      );
      return;
    }

    setState(() => _saving = true);
    await DatabaseService.instance.updateUser(userId, {
      'full_name': _name,
      'contact': _contact,
      'address': _address,
      'age': _age,
      'fitzpatrick': _fitzpatrick,
      'notes': _notes,
    });
    
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isGuest = AuthService.instance.isGuest;

    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profile', style: AppTheme.display(size: 24)),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: AppTheme.refer),
                  tooltip: 'Log out',
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Photo placeholder
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.filmSoft,
                    child: Icon(Icons.person, size: 50, color: AppTheme.slate),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.aperture,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            if (isGuest)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.watch.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.watch),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.watch),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are using Guest Mode. Create an account to save your profile details.',
                        style: AppTheme.body(size: 13, color: AppTheme.ink),
                      ),
                    ),
                  ],
                ),
              ),

            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(labelText: 'Full Name'),
              enabled: !isGuest,
              onSaved: (v) => _name = v ?? '',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: _age?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Age'),
                    enabled: !isGuest,
                    keyboardType: TextInputType.number,
                    onSaved: (v) => _age = int.tryParse(v ?? ''),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: _contact,
                    decoration: const InputDecoration(labelText: 'Contact / Phone'),
                    enabled: !isGuest,
                    onSaved: (v) => _contact = v ?? '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              initialValue: _address,
              decoration: const InputDecoration(labelText: 'Address'),
              enabled: !isGuest,
              maxLines: 2,
              onSaved: (v) => _address = v ?? '',
            ),
            const SizedBox(height: 24),
            
            Text('Fitzpatrick Skin Type', style: AppTheme.body(weight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _fitzpatrick,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _fitzpatrickOptions.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: AppTheme.body(size: 13)),
              )).toList(),
              onChanged: isGuest ? null : (v) => setState(() => _fitzpatrick = v),
              onSaved: (v) => _fitzpatrick = v,
              hint: const Text('Select your skin type'),
              isExpanded: true,
            ),
            const SizedBox(height: 8),
            Text(
              'SkinGuard model performance varies across skin types. Types V and VI '
              'were under-represented in the training data (11 images total).',
              style: AppTheme.body(size: 11, color: AppTheme.signal, height: 1.4),
            ),
            
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _notes,
              decoration: const InputDecoration(
                labelText: 'Medical Notes',
                hintText: 'Any personal/family history of skin cancer...',
              ),
              enabled: !isGuest,
              maxLines: 3,
              onSaved: (v) => _notes = v ?? '',
            ),
            
            const SizedBox(height: 32),
            FilledButton(
              onPressed: isGuest || _saving ? null : _save,
              child: _saving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Profile'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
