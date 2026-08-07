// ═══════════════════════════════════════════════════════════════
//  PDF Service (§5)
//
//  Exports scan results to a standardized PDF report.
//  Layout matching §5 spec exactly.
//  Disclaimer on the page, not in settings.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/scan_result.dart';
import 'auth_service.dart';

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  Future<void> exportScan({
    required File imageFile,
    required ScanResult result,
    required String scanId,
    required DateTime timestamp,
    String? bodySite,
  }) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(await imageFile.readAsBytes());
    
    final dateStr = DateFormat('d MMM yyyy').format(timestamp).toUpperCase();
    final timeStr = DateFormat('HH:mm').format(timestamp);
    final patientName = AuthService.instance.currentFullName ?? 'Guest';
    
    // We don't have age in AuthService yet, but we'd fetch it from DB in a real app
    final patientAge = 'N/A'; 
    final bSite = bodySite ?? 'Unknown';
    
    final riskColor = _getPdfRiskColor(result.risk);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SKINGUARD AI', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$scanId  ·  $dateStr  ·  $timeStr', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 24),
              
              // Body
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Image
                  pw.Container(
                    width: 200,
                    height: 200,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Image(image, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(width: 32),
                  
                  // Results
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RESULT', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                        pw.SizedBox(height: 8),
                        
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(result.melanomaPercent, style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: riskColor)),
                            pw.SizedBox(width: 8),
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 6),
                              child: pw.Text('melanoma risk', style: const pw.TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                        
                        pw.Text('Cancer risk ${result.cancerPercent}   ·   ${result.risk.name.toUpperCase()}', 
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: riskColor)),
                        
                        pw.SizedBox(height: 48),
                        
                        // Patient & Metadata Table
                        pw.Table(
                          columnWidths: {
                            0: const pw.FlexColumnWidth(2),
                            1: const pw.FlexColumnWidth(3),
                            2: const pw.FlexColumnWidth(1.5),
                            3: const pw.FlexColumnWidth(3),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Text('Patient', style: const pw.TextStyle(color: PdfColors.grey700)),
                                pw.Text('$patientName, $patientAge'),
                                pw.Text('Site', style: const pw.TextStyle(color: PdfColors.grey700)),
                                pw.Text(bSite),
                              ]
                            ),
                            pw.TableRow(children: [pw.SizedBox(height: 12), pw.SizedBox(height: 12), pw.SizedBox(height: 12), pw.SizedBox(height: 12)]),
                            pw.TableRow(
                              children: [
                                pw.Text('Threshold', style: const pw.TextStyle(color: PdfColors.grey700)),
                                pw.Text('0.385'),
                                pw.Text('Model', style: const pw.TextStyle(color: PdfColors.grey700)),
                                pw.Text('v10'),
                              ]
                            ),
                          ]
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 32),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 16),
              
              // Disclaimer
              pw.Text(
                'NOT A DIAGNOSIS. Produced by an automated screening aid\n'
                'for triage support only. Clinical assessment by a\n'
                'qualified dermatologist is required.',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800, lineSpacing: 1.5),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${scanId}_Report.pdf',
    );
  }

  PdfColor _getPdfRiskColor(RiskBand risk) {
    switch (risk) {
      case RiskBand.low: return PdfColor.fromHex('#2D6A4F');
      case RiskBand.moderate: return PdfColor.fromHex('#B87333');
      case RiskBand.high: return PdfColor.fromHex('#9B2226');
      case RiskBand.veryHigh: return PdfColor.fromHex('#9B2226');
    }
  }
}
