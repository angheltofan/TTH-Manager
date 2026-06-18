import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/monthly_management_report.dart';

/// Builds the A4 "Raport managerial lunar" PDF. Visually mirrors the
/// existing child activity PDF: same Open Sans (via PdfGoogleFonts so
/// Romanian diacritics render), same logo placement, same simple
/// section headers.
class MonthlyManagementPdfService {
  MonthlyManagementPdfService();

  static const _logoAsset = 'assets/images/app_logo.png';

  static const _monthNames = [
    '',
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];

  Future<Uint8List> build(MonthlyManagementReportData data) async {
    final regular = await PdfGoogleFonts.openSansRegular();
    final bold = await PdfGoogleFonts.openSansBold();
    final italic = await PdfGoogleFonts.openSansItalic();
    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
    );

    final logo = await _loadLogo();
    final monthLabel =
        '${_monthNames[data.month]} ${data.year}'.toUpperCase();

    final doc = pw.Document(
      title: 'Raport managerial lunar – ${_monthNames[data.month]} ${data.year}',
      author: 'Tales & Tech HUB',
      creator: 'TTH Manager',
      theme: theme,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        header: (ctx) => _header(
          ctx: ctx,
          data: data,
          monthLabel: monthLabel,
          logo: logo,
          bold: bold,
        ),
        footer: (ctx) => _footer(ctx, bold),
        build: (ctx) => [
          _sectionTitle('Rezumat executiv'),
          _execSummary(data.executiveSummary, bold),
          pw.SizedBox(height: 18),

          _sectionTitle('Situația copiilor'),
          _twoColumnList([
            ['Total copii activi', '${data.children.totalActive}'],
            ['Copii plătitori', '${data.children.payingActive}'],
            ['Copii cu participare gratuită', '${data.children.freeActive}'],
            ['Copii noi în lună', '${data.children.newThisMonth}'],
            ['Copii inactivi', '${data.children.totalInactive}'],
            ['Copii fără atelier activ', '${data.children.withoutActiveWorkshop}'],
            ['Copii fără părinte asociat', '${data.children.withoutParentLink}'],
          ], bold),
          pw.SizedBox(height: 18),

          _sectionTitle('Situația atelierelor'),
          _workshopsBlock(data.workshops, bold),
          pw.SizedBox(height: 18),

          _sectionTitle('Prezență'),
          _attendanceBlock(data.attendance, bold),
          pw.SizedBox(height: 18),

          _sectionTitle('Plăți'),
          if (data.children.freeActive > 0) ...[
            pw.Text(
              'Notă: cei ${data.children.freeActive} copii cu participare '
              'gratuită sunt excluși din toate cifrele financiare de mai jos.',
              style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
          ],
          _paymentsBlock(data.payments, bold),
          pw.SizedBox(height: 18),

          _sectionTitle('Traineri'),
          _trainersBlock(data.trainers, bold),
          pw.SizedBox(height: 18),

          _sectionTitle('Portal părinți'),
          _parentPortalBlock(data.parentPortal, bold),
          pw.SizedBox(height: 18),

          _sectionTitle('Alerte manageriale'),
          _bulletList(data.alerts, bold),
          pw.SizedBox(height: 18),

          _sectionTitle('Recomandări'),
          _bulletList(data.recommendations, bold),
          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Text(
              'Raport generat automat de TTH Manager.',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header / footer ────────────────────────────────────────────────────────

  pw.Widget _header({
    required pw.Context ctx,
    required MonthlyManagementReportData data,
    required String monthLabel,
    required pw.MemoryImage? logo,
    required pw.Font bold,
  }) {
    final isFirstPage = ctx.pageNumber == 1;
    if (!isFirstPage) {
      return pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
          ),
        ),
        child: pw.Text(
          'Raport managerial lunar – $monthLabel',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Container(
                  width: 36,
                  height: 36,
                  margin: const pw.EdgeInsets.only(right: 10),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Text('Tales & Tech HUB',
                  style: pw.TextStyle(fontSize: 12, font: bold)),
              pw.Spacer(),
              pw.Text(
                'Generat: ${_formatDateTime(data.generatedAt)}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'RAPORT MANAGERIAL LUNAR',
              style: pw.TextStyle(fontSize: 18, font: bold, letterSpacing: 1.5),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              monthLabel,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey800,
                font: bold,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 1, color: PdfColors.grey400),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, pw.Font bold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Text('Tales & Tech HUB',
              style: pw.TextStyle(
                fontSize: 9,
                font: bold,
                color: PdfColors.grey700,
              )),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text('Raport generat automat de TTH Manager.',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ),
          pw.Text('Pagina ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  // ── Section primitives ────────────────────────────────────────────────────

  pw.Widget _sectionTitle(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
        ),
      ),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  pw.Widget _twoColumnList(List<List<String>> rows, pw.Font bold) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(180),
        1: pw.FlexColumnWidth(),
      },
      children: [
        for (final row in rows)
          pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(row[0],
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    font: bold,
                  )),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child:
                  pw.Text(row[1], style: const pw.TextStyle(fontSize: 10)),
            ),
          ]),
      ],
    );
  }

  pw.Widget _bulletList(List<String> items, pw.Font bold) {
    if (items.isEmpty) return _muted('Nimic de raportat.');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 4,
                  height: 4,
                  margin: const pw.EdgeInsets.only(top: 4, right: 8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.black,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(item,
                      style: const pw.TextStyle(fontSize: 10, height: 1.4)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _muted(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
            fontStyle: pw.FontStyle.italic,
          )),
    );
  }

  // ── Section bodies ────────────────────────────────────────────────────────

  pw.Widget _execSummary(ReportExecutiveSummary s, pw.Font bold) {
    final rate = s.attendanceRate == null ? '—' : '${s.attendanceRate}%';
    return _twoColumnList([
      ['Copii activi', '${s.activeChildren}'],
      ['Copii noi în lună', '${s.newChildren}'],
      ['Ateliere desfășurate', '${s.sessionsHeld}'],
      ['Prezență medie', rate],
      ['Plăți confirmate (lună)', '${s.paidCycles}'],
      ['Plăți neconfirmate/restante', '${s.unpaidCycles}'],
      ['Demo workshops', '${s.demoCount}'],
    ], bold);
  }

  pw.Widget _workshopsBlock(ReportWorkshopsStatus w, pw.Font bold) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _twoColumnList([
        ['Total sesiuni desfășurate', '${w.sessionsHeld}'],
        ['Sesiuni fără copii prezenți', '${w.withoutChildren}'],
        ['Sesiuni fără trainer', '${w.withoutTrainer}'],
      ], bold),
      pw.SizedBox(height: 10),
      if (w.byType.isNotEmpty) ...[
        pw.Text('Ateliere pe tip',
            style: pw.TextStyle(fontSize: 10, font: bold)),
        pw.SizedBox(height: 4),
        _simpleTable(
          headers: const ['Tip', 'Sesiuni'],
          rows: [
            for (final t in w.byType) [t.type, '${t.count}'],
          ],
          bold: bold,
        ),
        pw.SizedBox(height: 10),
      ],
      if (w.mostPopular.isNotEmpty) ...[
        pw.Text('Cele mai populate ateliere',
            style: pw.TextStyle(fontSize: 10, font: bold)),
        pw.SizedBox(height: 4),
        _simpleTable(
          headers: const ['Atelier', 'Prezențe'],
          rows: [
            for (final t in w.mostPopular) [t.title, '${t.attendees}'],
          ],
          bold: bold,
        ),
      ],
    ]);
  }

  pw.Widget _attendanceBlock(ReportAttendanceStatus a, pw.Font bold) {
    final rate = a.attendanceRate == null ? '—' : '${a.attendanceRate}%';
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _twoColumnList([
        ['Total prezențe', '${a.totalPresent}'],
        ['Total absențe', '${a.totalAbsent}'],
        ['Total motivate', '${a.totalMotivated}'],
        ['Rata de prezență', rate],
      ], bold),
      pw.SizedBox(height: 10),
      if (a.topChildrenByAttendance.isNotEmpty) ...[
        pw.Text('Top copii după prezență',
            style: pw.TextStyle(fontSize: 10, font: bold)),
        pw.SizedBox(height: 4),
        _simpleTable(
          headers: const ['Copil', 'Rată', 'Sesiuni'],
          rows: [
            for (final r in a.topChildrenByAttendance)
              [r.name, '${r.ratePercent}%', '${r.totalSessions}'],
          ],
          bold: bold,
        ),
        pw.SizedBox(height: 10),
      ],
      if (a.topChildrenByAbsences.isNotEmpty) ...[
        pw.Text('Copii cu cele mai multe absențe',
            style: pw.TextStyle(fontSize: 10, font: bold)),
        pw.SizedBox(height: 4),
        _simpleTable(
          headers: const ['Copil', 'Absențe'],
          rows: [
            for (final r in a.topChildrenByAbsences)
              [r.name, '${r.count}'],
          ],
          bold: bold,
        ),
        pw.SizedBox(height: 10),
      ],
      if (a.workshopsWithHighAbsenceRate.isNotEmpty) ...[
        pw.Text('Ateliere cu rată mare de absență',
            style: pw.TextStyle(fontSize: 10, font: bold)),
        pw.SizedBox(height: 4),
        _simpleTable(
          headers: const ['Atelier', 'Rată absențe', 'Sesiuni'],
          rows: [
            for (final r in a.workshopsWithHighAbsenceRate)
              [r.name, '${r.ratePercent}%', '${r.totalSessions}'],
          ],
          bold: bold,
        ),
      ],
    ]);
  }

  pw.Widget _paymentsBlock(ReportPaymentsStatus p, pw.Font bold) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _twoColumnList([
        ['Cicluri plătite (lună)', '${p.paidCycles}'],
        ['Cicluri neconfirmate / restante', '${p.unconfirmedCycles}'],
        ['Achitate în avans', '${p.advancePaidCycles}'],
        ['Cicluri anulate', '${p.cancelledCycles}'],
      ], bold),
      pw.SizedBox(height: 8),
      pw.Text(
        'Valoarea financiară nu poate fi calculată deoarece prețul per '
        'ședință nu este stocat.',
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey700,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
      pw.SizedBox(height: 10),
      if (p.paymentMethods.any((m) => m.count > 0)) ...[
        pw.Text('Metode de plată (cicluri plătite)',
            style: pw.TextStyle(fontSize: 10, font: bold)),
        pw.SizedBox(height: 4),
        _simpleTable(
          headers: const ['Metodă', 'Cicluri'],
          rows: [
            for (final m in p.paymentMethods) [m.method, '${m.count}'],
          ],
          bold: bold,
        ),
        pw.SizedBox(height: 10),
      ],
      if (p.childrenWithUnconfirmedPayments.isNotEmpty) ...[
        pw.Text('Copii cu plăți neconfirmate',
            style: pw.TextStyle(fontSize: 10, font: bold)),
        pw.SizedBox(height: 4),
        _bulletList(p.childrenWithUnconfirmedPayments, bold),
      ],
    ]);
  }

  pw.Widget _parentPortalBlock(ReportParentPortalStatus p, pw.Font bold) {
    final rate = p.activationRatePercent == null
        ? '—'
        : '${p.activationRatePercent}%';
    return _twoColumnList([
      ['Conturi de părinte', '${p.totalParentAccounts}'],
      ['Părinți activați', '${p.activatedParents}'],
      ['Rată activare', rate],
      ['Invitații în așteptare', '${p.pendingInvitations}'],
      ['Invitații expirate', '${p.expiredInvitations}'],
      ['Copii cu părinte asociat', '${p.childrenLinkedToParent}'],
      ['Copii activi fără părinte asociat', '${p.childrenWithoutParentLink}'],
    ], bold);
  }

  pw.Widget _trainersBlock(ReportTrainersStatus t, pw.Font bold) {
    if (t.perTrainer.isEmpty) {
      return _muted('Nu există traineri configurați în aplicație.');
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _twoColumnList([
        ['Traineri activi', '${t.totalTrainers}'],
      ], bold),
      pw.SizedBox(height: 10),
      _simpleTable(
        headers: const [
          'Trainer',
          'Sesiuni (lună)',
          'Prezențe marcate',
          'Ateliere active',
        ],
        rows: [
          for (final r in t.perTrainer)
            [
              r.name,
              '${r.sessions}',
              '${r.attendanceMarked}',
              '${r.activeWorkshops}',
            ],
        ],
        bold: bold,
      ),
    ]);
  }

  // ── Tables ────────────────────────────────────────────────────────────────

  pw.Widget _simpleTable({
    required List<String> headers,
    required List<List<String>> rows,
    required pw.Font bold,
  }) {
    if (rows.isEmpty) return _muted('Nu există date pentru această secțiune.');
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5, vertical: 5),
                child: pw.Text(h,
                    style: pw.TextStyle(fontSize: 9, font: bold)),
              ),
          ],
        ),
        for (final row in rows)
          pw.TableRow(children: [
            for (final cell in row)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5, vertical: 4),
                child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
              ),
          ]),
      ],
    );
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  String _formatDateTime(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year} $hh:$mi';
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load(_logoAsset);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
