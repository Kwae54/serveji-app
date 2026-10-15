import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../../features/order/model/restaurant_order.dart';
import '../../features/billing/model/bill.dart';
import 'print_output.dart';

class ThermalPrintService {
  static const double _paperWidth = 80 * PdfPageFormat.mm;

  static const double _margin = 2 * PdfPageFormat.mm;

  static double get _printerOffsetQrX {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return isAndroid ? 0 : -4 * PdfPageFormat.mm;
  }

  static Future<pw.Font> _regularFont() async {
    final data = await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');

    return pw.Font.ttf(data);
  }

  static Future<pw.Font> _boldFont() async {
    final data = await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf');

    return pw.Font.ttf(data);
  }

  // =========================================================
  // QR
  // =========================================================

  static Future<void> printSessionQR({
    required String restaurantName,
    required String tableNo,
    required String orderUrl,
  }) async {
    final regular = await _regularFont();
    final bold = await _boldFont();

    final pdf = pw.Document();

    final format = PdfPageFormat(
      _paperWidth,
      100 * PdfPageFormat.mm,
      marginLeft: _margin,
      marginRight: _margin,
      marginTop: _margin,
      marginBottom: _margin,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) {
          final contentWidth = _paperWidth - (_margin * 2);

          return pw.Transform.translate(
            offset: PdfPoint(_printerOffsetQrX, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: contentWidth,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    restaurantName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 18),
                  ),
                ),

                pw.SizedBox(height: 5),

                pw.Container(
                  width: contentWidth,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '*สำหรับพนักงานเท่านั้น*',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 14),
                  ),
                ),

                pw.Container(
                  width: contentWidth,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'โต๊ะ $tableNo',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 16),
                  ),
                ),

                pw.SizedBox(height: 5),

                pw.Container(
                  width: contentWidth,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'สแกน QR เพื่อสั่งอาหาร',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 10),
                  ),
                ),

                pw.SizedBox(height: 10),

                pw.Container(
                  width: contentWidth,
                  alignment: pw.Alignment.center,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: orderUrl,
                    width: 48 * PdfPageFormat.mm,
                    height: 48 * PdfPageFormat.mm,
                  ),
                ),

                pw.SizedBox(height: 8),

                pw.Container(
                  width: contentWidth,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'กรุณาเก็บ QR นี้ไว้จนกว่าจะชำระเงิน',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();

    await printPdfBytes(
      bytes: bytes,
      name: 'serveji-qr-$tableNo.pdf',
      format: format,
    );
  }

  // =========================================================
  // Receipt
  // =========================================================

  static Future<void> printBill({required Bill bill}) async {
    final regular = await _regularFont();
    final bold = await _boldFont();

    final receiptItems = _groupReceiptItems(bill);

    final paymentQrImage = await _loadPaymentQrImage(bill.paymentQrImageUrl);

    final pdf = pw.Document();

    final qrExtraHeightMm = paymentQrImage != null ? 62 : 0;

    final heightMm =
        105 +
        (receiptItems.length * 12) +
        (bill.discounts.length * 8) +
        qrExtraHeightMm;

    final format = PdfPageFormat(
      _paperWidth,
      heightMm * PdfPageFormat.mm,
      marginLeft: 4 * PdfPageFormat.mm,
      marginRight: 12 * PdfPageFormat.mm,
      marginTop: 4 * PdfPageFormat.mm,
      marginBottom: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) {
          return pw.Container(
            width: 64 * PdfPageFormat.mm,
            child: pw.DefaultTextStyle(
              style: pw.TextStyle(font: regular, fontSize: 9),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      bill.restaurantName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: bold, fontSize: 16),
                    ),
                  ),

                  pw.SizedBox(height: 3),

                  pw.Center(
                    child: pw.Text(
                      'ใบแจ้งยอด',
                      style: pw.TextStyle(font: bold, fontSize: 12),
                    ),
                  ),

                  pw.Center(
                    child: pw.Text(
                      'BILL',
                      style: pw.TextStyle(font: regular, fontSize: 8),
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  _textRow('โต๊ะ', bill.tableNo, regular),

                  _textRow('วันที่', _formatDateTime(DateTime.now()), regular),

                  pw.SizedBox(height: 6),

                  _divider(),

                  pw.SizedBox(height: 5),

                  // =========================
                  // Items
                  // =========================
                  ...receiptItems.map((item) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 7),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Text(
                            item.menuItemName,
                            style: pw.TextStyle(font: regular, fontSize: 9),
                          ),

                          pw.SizedBox(height: 2),

                          pw.SizedBox(
                            width: 64 * PdfPageFormat.mm,
                            child: pw.Row(
                              children: [
                                pw.Text(
                                  '${item.quantity} x '
                                  '${_money(item.unitPriceSatang)}',
                                  style: pw.TextStyle(
                                    font: regular,
                                    fontSize: 8,
                                  ),
                                ),

                                pw.Spacer(),

                                pw.Text(
                                  _money(item.totalSatang),
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(
                                    font: regular,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  _divider(),

                  pw.SizedBox(height: 5),

                  // =========================
                  // Summary
                  // =========================
                  _moneyRow(
                    label: 'ยอดรวม',
                    value: bill.subtotalSatang,
                    font: regular,
                  ),

                  ...bill.discounts.map(
                    (discount) => _moneyRow(
                      label: discount.discountName,
                      value: -discount.discountAmountSatang,
                      font: regular,
                    ),
                  ),

                  if (bill.discountTotalSatang > 0)
                    _moneyRow(
                      label: 'ส่วนลดรวม',
                      value: -bill.discountTotalSatang,
                      font: regular,
                    ),

                  pw.SizedBox(height: 4),

                  _divider(),

                  pw.SizedBox(height: 5),

                  _moneyRow(
                    label: 'ยอดสุทธิ',
                    value: bill.totalSatang,
                    font: bold,
                    fontSize: 12,
                  ),

                  if (paymentQrImage != null) ...[
                    pw.SizedBox(height: 8),

                    _divider(),

                    pw.SizedBox(height: 7),

                    pw.Center(
                      child: pw.Text(
                        'สแกน QR เพื่อชำระเงิน',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: bold, fontSize: 10),
                      ),
                    ),

                    pw.SizedBox(height: 5),

                    pw.Center(
                      child: pw.Image(
                        paymentQrImage,
                        width: 44 * PdfPageFormat.mm,
                        height: 44 * PdfPageFormat.mm,
                        fit: pw.BoxFit.contain,
                      ),
                    ),

                    pw.SizedBox(height: 4),

                    pw.Center(
                      child: pw.Text(
                        'ยอดชำระ ${_money(bill.totalSatang)} บาท',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: bold, fontSize: 10),
                      ),
                    ),
                  ],

                  pw.SizedBox(height: 10),

                  pw.Center(
                    child: pw.Text(
                      'กรุณาตรวจสอบรายการก่อนชำระเงิน',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: regular, fontSize: 8),
                    ),
                  ),

                  pw.SizedBox(height: 3),

                  pw.Center(
                    child: pw.Text(
                      'ขอบคุณที่ใช้บริการ',
                      style: pw.TextStyle(font: regular, fontSize: 8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();

    await printPdfBytes(
      bytes: bytes,
      name: 'bill-${bill.tableNo}.pdf',
      format: format,
    );
  }

  // =========================================================
  // Kitchen Order
  // =========================================================

  static Future<void> printKitchenOrder({
    required RestaurantOrder order,
    required String restaurantName,
  }) async {
    final regular = await _regularFont();
    final bold = await _boldFont();

    final pdf = pw.Document();

    double heightMm = 70;

    for (final item in order.items) {
      // พื้นที่ชื่อเมนู
      heightMm += 16;

      // เผื่อชื่อเมนูยาว
      if (item.menuItemName.length > 24) {
        heightMm += 6;
      }

      final note = item.note?.trim() ?? '';

      if (note.isNotEmpty) {
        heightMm += 8;

        if (note.length > 30) {
          heightMm += 6;
        }
      }
    }

    final customerNote = order.customerNote?.trim() ?? '';

    if (customerNote.isNotEmpty) {
      heightMm += 14;

      if (customerNote.length > 40) {
        heightMm += 8;
      }
    }

    // เผื่อด้านล่างสำหรับข้อความ/ตัดกระดาษ
    heightMm += 20;

    if (heightMm < 100) {
      heightMm = 100;
    }

    final format = PdfPageFormat(
      _paperWidth,
      heightMm * PdfPageFormat.mm,
      marginLeft: 4 * PdfPageFormat.mm,
      marginRight: 4 * PdfPageFormat.mm,
      marginTop: 3 * PdfPageFormat.mm,
      marginBottom: 3 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) {
          return pw.SizedBox(
            width: 72 * PdfPageFormat.mm,
            child: pw.DefaultTextStyle(
              style: pw.TextStyle(font: regular, fontSize: 11),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'KITCHEN ORDER',
                      style: pw.TextStyle(font: bold, fontSize: 10),
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  pw.Table(
                    columnWidths: {
                      0: pw.FixedColumnWidth(18 * PdfPageFormat.mm),
                      1: pw.FixedColumnWidth(50 * PdfPageFormat.mm),
                    },
                    children: [
                      _kitchenInfoTableRow(
                        label: 'โต๊ะ',
                        value: order.tableNo?.isNotEmpty == true
                            ? order.tableNo!
                            : '-',
                        regular: regular,
                        bold: bold,
                        valueFontSize: 16,
                      ),

                      _kitchenInfoTableRow(
                        label: 'Order',
                        value: order.orderCode,
                        regular: regular,
                        bold: bold,
                      ),

                      _kitchenInfoTableRow(
                        label: 'เวลา',
                        value: _formatDateTime(
                          order.createdAt ?? DateTime.now(),
                        ),
                        regular: regular,
                        bold: bold,
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 7),

                  _divider(),

                  pw.SizedBox(height: 7),

                  // =========================
                  // Items
                  // =========================
                  ...order.items.map((item) {
                    final note = item.note?.trim() ?? '';

                    final cancelled = item.status.toUpperCase() == 'CANCELLED';

                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 14 * PdfPageFormat.mm,
                                child: pw.Text(
                                  '${item.quantity} x',
                                  style: pw.TextStyle(font: bold, fontSize: 18),
                                ),
                              ),

                              pw.Expanded(
                                child: pw.Text(
                                  cancelled
                                      ? '${item.menuItemName} (ยกเลิก)'
                                      : item.menuItemName,
                                  style: pw.TextStyle(font: bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),

                          if (note.isNotEmpty) ...[
                            pw.SizedBox(height: 4),

                            pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.all(5),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(width: 0.7),
                              ),
                              child: pw.Text(
                                'หมายเหตุ: $note',
                                style: pw.TextStyle(font: bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  _divider(),

                  // =========================
                  // Customer note
                  // =========================
                  if (customerNote.isNotEmpty) ...[
                    pw.SizedBox(height: 7),

                    pw.Text(
                      'หมายเหตุลูกค้า',
                      style: pw.TextStyle(font: bold, fontSize: 11),
                    ),

                    pw.SizedBox(height: 3),

                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 1),
                      ),
                      child: pw.Text(
                        customerNote,
                        style: pw.TextStyle(font: bold, fontSize: 12),
                      ),
                    ),
                  ],

                  pw.SizedBox(height: 10),

                  pw.Center(
                    child: pw.Text(
                      '*** กรุณาตรวจสอบรายการ ***',
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();

    await printPdfBytes(
      bytes: bytes,
      name: 'kitchen-${order.orderCode}.pdf',
      format: format,
    );
  }

  // static const double _printerOffsetX = 3 * PdfPageFormat.mm;

  static pw.Widget _divider() {
    return pw.Container(height: 0.5, color: PdfColors.grey600);
  }

  static pw.Widget _textRow(String left, String right, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Text(left, style: pw.TextStyle(font: font, fontSize: 8)),

          pw.Spacer(),

          pw.Text(
            right,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: font, fontSize: 8),
          ),
        ],
      ),
    );
  }

  static pw.Widget _moneyRow({
    required String label,
    required int value,
    required pw.Font font,
    double fontSize = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: fontSize),
          ),

          pw.Spacer(),

          pw.Text(
            value < 0 ? '-${_money(-value)}' : _money(value),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: font, fontSize: fontSize),
          ),
        ],
      ),
    );
  }

  static pw.TableRow _kitchenInfoTableRow({
    required String label,
    required String value,
    required pw.Font regular,
    required pw.Font bold,
    double valueFontSize = 9,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 9)),
        ),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                value,
                style: pw.TextStyle(font: bold, fontSize: valueFontSize),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _money(int satang) {
    final baht = satang ~/ 100;
    final decimal = satang % 100;

    return '$baht.${decimal.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }

  static Future<pw.MemoryImage?> _loadPaymentQrImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    try {
      final url = AppConfig.imageUrl(imagePath.trim());

      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final data = response.data;

      if (data == null || data.isEmpty) {
        return null;
      }

      return pw.MemoryImage(Uint8List.fromList(data));
    } catch (_) {
      // ถ้าโหลด QR ไม่ได้ ให้ยังพิมพ์ Bill ได้ตามปกติ
      return null;
    }
  }

  static List<_ReceiptItem> _groupReceiptItems(Bill bill) {
    final grouped = <String, _ReceiptItem>{};

    for (final item in bill.items) {
      final name = item.menuItemName.trim();

      // ชื่อเดียวกัน + ราคาเดียวกัน
      // จึงถือว่าเป็นรายการเดียวกันบนใบเสร็จ
      final key =
          '${name.toLowerCase()}|'
          '${item.unitPriceSatang}';

      final existing = grouped[key];

      if (existing == null) {
        grouped[key] = _ReceiptItem(
          menuItemName: name,
          unitPriceSatang: item.unitPriceSatang,
          quantity: item.quantity,
          totalSatang: item.totalSatang,
        );

        continue;
      }

      existing.quantity += item.quantity;

      existing.totalSatang += item.totalSatang;
    }

    return grouped.values.toList();
  }
}

class _ReceiptItem {
  final String menuItemName;
  final int unitPriceSatang;

  int quantity;
  int totalSatang;

  _ReceiptItem({
    required this.menuItemName,
    required this.unitPriceSatang,
    required this.quantity,
    required this.totalSatang,
  });
}
