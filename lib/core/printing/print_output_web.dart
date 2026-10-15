import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

Future<void> printPdfBytes({
  required Uint8List bytes,
  required String name,
  required PdfPageFormat format,
}) async {
  await Printing.layoutPdf(
    name: name,
    format: format,
    onLayout: (_) async => bytes,
  );
}
