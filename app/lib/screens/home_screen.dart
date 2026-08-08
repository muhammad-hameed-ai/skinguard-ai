// ═══════════════════════════════════════════════════════════════
//  Home Screen (§3.4)
//
//  Greeting with day/date. Dark card with aperture motif.
//  Camera + Gallery actions. Recent scans preview.
//  Bottom nav: Scan · History · Learn · Profile.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/aperture_view.dart';
import '../services/auth_service.dart';
import '../services/inference_service.dart';
import '../services/database_service.dart';
import '../services/image_storage.dart';
import 'processing_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'capture_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _ScanTab(),
      const HistoryScreen(),
      const _LearnTab(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_navIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.center_focus_strong), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Learn'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _ScanTab extends StatelessWidget {
  const _ScanTab();

  Future<void> _scanCamera(BuildContext context) async {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
  }

  Future<void> _scanGallery(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null || !context.mounted) return;

    final stored = await ImageStorage.persist(File(picked.path));
    if (!context.mounted) return;

    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(imageFile: stored),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final dateStr = DateFormat('EEEE, d MMMM').format(now);
    final name = AuthService.instance.currentFullName ?? 'there';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('$greeting,', style: AppTheme.body(size: 16, color: AppTheme.slate)),
            Text(name, style: AppTheme.display(size: 24)),
            Text(dateStr, style: AppTheme.mono(size: 12, color: AppTheme.slateSoft)),
            const SizedBox(height: 28),

            // Main scan card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const ApertureView(size: 160, showRing: true),
                  const SizedBox(height: 24),
                  Text('Scan a Lesion',
                      style: AppTheme.display(
                          size: 20, color: AppTheme.paper)),
                  const SizedBox(height: 8),
                  Text('Ensure good lighting and focus',
                      style: AppTheme.body(
                          size: 13, color: AppTheme.slateSoft)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _scanCamera(context),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _scanGallery(context),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.paper,
                            side: BorderSide(
                                color: AppTheme.paper.withOpacity(0.3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recent scans
            Text('Recent Scans',
                style: AppTheme.body(weight: FontWeight.w600, size: 16)),
            const SizedBox(height: 12),
            const _RecentScans(),

            const SizedBox(height: 24),
            Center(
              child: Text(
                'Screening aid only. Not a diagnosis.',
                style: AppTheme.body(size: 11, color: AppTheme.slateSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentScans extends StatelessWidget {
  const _RecentScans();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.instance.getScans(
          userId: AuthService.instance.currentUserId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            child: Center(
              child: Text('No scans yet. Take your first scan above.',
                  style: AppTheme.body(color: AppTheme.slateSoft)),
            ),
          );
        }
        final scans = snap.data!.take(3).toList();
        return Column(
          children: scans.map((s) {
            final risk = s['risk_level'] as String;
            final date = DateTime.tryParse(s['created_at'] as String? ?? '');
            final dateStr = date != null
                ? DateFormat('EEE d MMM · HH:mm').format(date)
                : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.line),
              ),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48, height: 48,
                      child: File(s['image_path'] as String).existsSync()
                          ? Image.file(File(s['image_path'] as String),
                              fit: BoxFit.cover)
                          : Container(color: AppTheme.filmSoft),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['scan_id'] as String? ?? '',
                            style: AppTheme.mono(size: 12, color: AppTheme.slate)),
                        Text(dateStr,
                            style: AppTheme.body(size: 12, color: AppTheme.slateSoft)),
                      ],
                    ),
                  ),
                  Text(
                    '${risk.riskGlyph} ${risk.riskLabel}',
                    style: AppTheme.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: risk.riskColor),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _LearnTab extends StatelessWidget {
  const _LearnTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('Learn', style: AppTheme.display(size: 24)),
            const SizedBox(height: 20),
            _learnCard('ABCDE Rule', 'Asymmetry, Border, Colour, Diameter, '
                'Evolving — the clinical framework for assessing moles.', Icons.rule),
            _learnCard('Self-Examination', 'Check your skin monthly. Use a mirror '
                'for hard-to-see areas. Note any changes.', Icons.search),
            _learnCard('When to See a Doctor', 'Any mole that changes in size, '
                'shape, or colour. Any new mole after age 30.', Icons.medical_services),
            _learnCard('Fitzpatrick Skin Types', 'Your skin type affects your '
                'risk level. Types I–II have the highest melanoma risk.', Icons.palette),
            const SizedBox(height: 20),
            _modelDetails(),
          ],
        ),
      ),
    );
  }

  Widget _learnCard(String title, String body, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.aperture, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.body(weight: FontWeight.w600, size: 15)),
                const SizedBox(height: 4),
                Text(body, style: AppTheme.body(size: 13, color: AppTheme.slate, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// §7 — Limitations to surface in-app
  Widget _modelDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.filmSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Model Details & Limitations',
              style: AppTheme.body(weight: FontWeight.w600, size: 15)),
          const SizedBox(height: 12),
          ...[
            'Melanoma head trained on dermoscopy; smartphone performance unproven — the cancer head is the statistically supported claim for phone photos.',
            'Domain gap measured: AUC 0.494 unadapted → 0.778 adapted.',
            'Cancer risk is a stratifier, not a calibrated probability (Brier 0.19). Treat it as a range, not an exact number.',
            'Wound rejection trained on synthetic images only.',
            'Fitzpatrick V–VI under-represented (10 and 1 images) — dark-skin performance unvalidated, a genuine gap for a Pakistan deployment.',
            'CAM peak localisation 68.4%.',
            'Screening aid only. Not a diagnosis.',
          ].map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: AppTheme.body(color: AppTheme.signal)),
                Expanded(child: Text(t,
                    style: AppTheme.body(size: 12, color: AppTheme.slate, height: 1.5))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
