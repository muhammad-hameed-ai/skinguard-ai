// ═══════════════════════════════════════════════════════════════
//  History Screen (§3.10)
//
//  Grouped by month, filter chips (All · Refer · Watch · Clear).
//  Each row: small aperture thumbnail, body site, day + date + time,
//  scan ID, percentage, risk word.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'All';
  final _filters = ['All', 'Refer', 'Watch', 'Clear'];

  // Map filter string to risk band strings
  List<String> _getRiskBandsForFilter(String filter) {
    switch (filter) {
      case 'Refer': return ['veryHigh', 'high'];
      case 'Watch': return ['moderate'];
      case 'Clear': return ['low'];
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Scan History', style: AppTheme.display(size: 24)),
          ),
          
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = f),
                    backgroundColor: AppTheme.filmSoft,
                    selectedColor: AppTheme.aperture.withOpacity(0.1),
                    checkmarkColor: AppTheme.aperture,
                    labelStyle: AppTheme.body(
                      color: isSelected ? AppTheme.aperture : AppTheme.slate,
                      weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.aperture : AppTheme.line,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseService.instance.getScans(
                userId: AuthService.instance.currentUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final allScans = snapshot.data ?? [];
                
                // Apply filter
                final filtered = _selectedFilter == 'All' 
                  ? allScans 
                  : allScans.where((s) {
                      final risk = s['risk_level'] as String;
                      return _getRiskBandsForFilter(_selectedFilter).contains(risk);
                    }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No scans found', 
                      style: AppTheme.body(color: AppTheme.slateSoft)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final scan = filtered[index];
                    return _HistoryRow(scan: scan);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> scan;
  const _HistoryRow({required this.scan});

  @override
  Widget build(BuildContext context) {
    final risk = scan['risk_level'] as String;
    final date = DateTime.tryParse(scan['created_at'] as String? ?? '');
    // Day name included because people recall days better than dates.
    final dateStr = date != null ? DateFormat('EEE d MMM · HH:mm').format(date).toUpperCase() : '';
    final site = scan['body_site'] as String? ?? 'Unknown';
    final scanId = scan['scan_id'] as String? ?? '';
    final melProb = (scan['melanoma_prob'] as num).toDouble();
    final melPercent = '${(melProb.clamp(0.01, 0.99) * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Aperture thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.line),
            ),
            child: ClipOval(
              child: File(scan['image_path'] as String).existsSync()
                  ? Image.file(File(scan['image_path'] as String), fit: BoxFit.cover)
                  : Container(color: AppTheme.filmSoft),
            ),
          ),
          const SizedBox(width: 16),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(site, style: AppTheme.body(weight: FontWeight.w600, size: 15)),
                    Text(scanId, style: AppTheme.mono(size: 12, color: AppTheme.slateSoft)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: AppTheme.mono(size: 11, color: AppTheme.slate)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${risk.riskGlyph} ${risk.riskLabel}',
                      style: AppTheme.body(size: 13, weight: FontWeight.w600, color: risk.riskColor),
                    ),
                    const Spacer(),
                    Text(
                      melPercent,
                      style: AppTheme.mono(size: 13, weight: FontWeight.w600, color: risk.riskColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
