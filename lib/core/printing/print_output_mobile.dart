import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../printer/bluetooth_printer_service_mobile.dart';

Future<void> printPdfBytes({
  required Uint8List bytes,
  required String name,
  required PdfPageFormat format,
}) async {
  if (!Platform.isAndroid) {
    await Printing.layoutPdf(
      name: name,
      format: format,
      onLayout: (_) async => bytes,
    );
    return;
  }

  final printer = BluetoothPrinterService();

  final savedPrinter = await printer.getSavedPrinter();

  if (savedPrinter == null) {
    throw Exception(
      'ยังไม่ได้เลือกเครื่องพิมพ์ '
      'กรุณาเข้าเมนูตั้งค่าเครื่องพิมพ์ก่อน',
    );
  }

  final connected = await printer.ensureConnectedToSavedPrinter();

  if (!connected) {
    throw Exception('ไม่สามารถเชื่อมต่อ ${savedPrinter.name} ได้');
  }

  final profile = await CapabilityProfile.load();

  final generator = Generator(PaperSize.mm80, profile);

  final output = <int>[];

  const printerWidthDots = 576;

  await for (final page in Printing.raster(bytes, dpi: 203)) {
    final pngBytes = await page.toPng();

    final decoded = img.decodeImage(pngBytes);

    if (decoded == null) {
      throw Exception('ไม่สามารถแปลงเอกสารสำหรับพิมพ์ได้');
    }

    // =============================================
    // Transparent -> White
    // =============================================
    final whiteBackground = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 3,
    );

    img.fill(whiteBackground, color: img.ColorRgb8(255, 255, 255));

    img.compositeImage(whiteBackground, decoded);

    // =============================================
    // เอาพื้นขาวบน/ล่างที่ไม่จำเป็นออก
    // =============================================
    var printable = _trimVerticalWhitespace(whiteBackground, padding: 12);

    // =============================================
    // PDF 80 mm @ 203 DPI ≈ 640 dots
    // G80 printable area = 576 dots
    //
    // ห้าม resize 640 -> 576 เพราะจะทำให้ทุกอย่างเล็กลง
    // ให้ crop ตรงกลางแทนเพื่อรักษาขนาดจริง
    // =============================================
    if (printable.width > printerWidthDots) {
      final cropX = (printable.width - printerWidthDots) ~/ 2;

      printable = img.copyCrop(
        printable,
        x: cropX,
        y: 0,
        width: printerWidthDots,
        height: printable.height,
      );
    } else if (printable.width < printerWidthDots) {
      final canvas = img.Image(
        width: printerWidthDots,
        height: printable.height,
        numChannels: 3,
      );

      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

      img.compositeImage(
        canvas,
        printable,
        dstX: (printerWidthDots - printable.width) ~/ 2,
      );

      printable = canvas;
    }

    output.addAll(generator.imageRaster(printable, align: PosAlign.center));
  }

  // เดิม feed(3) ทำให้ด้านล่างยาวมาก
  output.addAll(generator.feed(1));

  output.addAll(generator.cut());

  final success = await printer.writeBytes(output);

  if (!success) {
    throw Exception('ส่งข้อมูลไปเครื่องพิมพ์ไม่สำเร็จ');
  }
}

img.Image _trimVerticalWhitespace(img.Image image, {int padding = 12}) {
  bool rowHasInk(int y) {
    for (var x = 0; x < image.width; x += 2) {
      final pixel = image.getPixel(x, y);

      if (pixel.r < 248 || pixel.g < 248 || pixel.b < 248) {
        return true;
      }
    }

    return false;
  }

  var top = 0;

  while (top < image.height && !rowHasInk(top)) {
    top++;
  }

  var bottom = image.height - 1;

  while (bottom >= top && !rowHasInk(bottom)) {
    bottom--;
  }

  if (top > bottom) {
    return image;
  }

  top = math.max(0, top - padding);

  bottom = math.min(image.height - 1, bottom + padding);

  return img.copyCrop(
    image,
    x: 0,
    y: top,
    width: image.width,
    height: bottom - top + 1,
  );
}
