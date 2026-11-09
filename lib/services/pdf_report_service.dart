import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../l10n/app_strings.dart';
import 'storage_service.dart';

class PdfReportService {
  static Future<Uint8List> generateStudyPdf({
    required SolarStudyRecord study,
    required String inspectorName,
    required String localeCode,
  }) async {
    final pdf = pw.Document();
    final s = AppStrings.get(localeCode);

    pw.MemoryImage? sigImage;
    if (study.signatureBase64 != null && study.signatureBase64!.isNotEmpty) {
      try {
        sigImage = pw.MemoryImage(base64Decode(study.signatureBase64!));
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('0B0F19'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          s.pdfReportTitle,
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('F59E0B'),
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'SunPath AR Pro • SimpleAppsPG Engineering Suite',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('94A3B8'),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      study.id,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                '${s.siteNameLabel}: ${study.siteName}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${s.latitudeLabel}: ${study.latitude.toStringAsFixed(4)}°  |  ${s.longitudeLabel}: ${study.longitude.toStringAsFixed(4)}°',
                style: const pw.TextStyle(fontSize: 10.5),
              ),
              pw.Text(
                '${s.dayOfYearLabel}: #${study.dayOfYear}  |  ${s.hourOfDayLabel}: ${study.solarHour.toStringAsFixed(1)} h',
                style: const pw.TextStyle(fontSize: 10.5),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),
              _row(s.solarElevation, '${study.elevationDeg.toStringAsFixed(2)}°'),
              _row(s.solarAzimuth, '${study.azimuthDeg.toStringAsFixed(2)}°'),
              _row(s.objectHeightLabel,
                  '${study.objectHeightMeters.toStringAsFixed(2)} m'),
              _row(s.shadowLengthResult,
                  '${study.shadowLengthMeters.toStringAsFixed(2)} m'),
              _row(s.pvOptimalTiltResult,
                  '${study.optimalTiltDeg.toStringAsFixed(1)}°'),
              _row(s.pvRowSpacingResult,
                  '${study.minRowSpacingMeters.toStringAsFixed(2)} m'),
              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 14),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (sigImage != null)
                        pw.Container(
                          height: 50,
                          width: 140,
                          child: pw.Image(sigImage),
                        ),
                      pw.Container(
                        width: 200,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(width: 1)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          '${s.pdfInspectorLabel}: $inspectorName',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    study.createdAtIso.split('T').first,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static Future<void> shareStudyPdf({
    required SolarStudyRecord study,
    required String inspectorName,
    required String localeCode,
  }) async {
    final bytes = await generateStudyPdf(
      study: study,
      inspectorName: inspectorName,
      localeCode: localeCode,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'SunPath_${study.id}.pdf',
    );
  }
}
