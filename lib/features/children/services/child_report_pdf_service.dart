import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/child_activity_report.dart';

/// Builds the A4 black-and-white "Raport activitate copil" PDF.
///
/// Layout: white background, Tales & Tech HUB logo + name top-left,
/// centered title, simple section dividers, tables with repeatable
/// headers. Romanian diacritics are handled by Open Sans loaded via
/// `PdfGoogleFonts` (the `printing` package downloads and caches the TTF;
/// no font files are exposed outside the app bundle).
class ChildReportPdfService {
  ChildReportPdfService();

  static const _logoAsset = 'assets/images/app_logo.png';

  Future<Uint8List> buildChildActivityReportPdf(
      ChildActivityReportData data) async {
    final regular = await PdfGoogleFonts.openSansRegular();
    final bold = await PdfGoogleFonts.openSansBold();
    final italic = await PdfGoogleFonts.openSansItalic();
    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
    );

    final logo = await _loadLogo();

    final doc = pw.Document(
      title: 'Raport activitate ${data.childInfo.fullName}',
      author: 'Tales & Tech HUB',
      creator: 'TTH Manager',
      theme: theme,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        header: (ctx) => _buildHeader(
          context: ctx,
          data: data,
          logo: logo,
          bold: bold,
        ),
        footer: (ctx) => _buildFooter(ctx, data, bold),
        build: (ctx) => [
          _sectionTitle('Date copil'),
          _childInfoTable(data.childInfo, bold),
          pw.SizedBox(height: 18),
          // "Programe active" covers both workshop enrollments and
          // Afterschool programs. The workshop-only legacy title
          // "Ateliere active" would mislead on a mixed child.
          _sectionTitle('Programe active'),
          _activeProgramsBlock(
              workshops: data.activeWorkshops,
              afterschool: data.activeAfterschoolPrograms,
              bold: bold),
          pw.SizedBox(height: 18),
          _sectionTitle('Situație generală'),
          _summaryBlock(data.summary, bold),
          pw.SizedBox(height: 18),
          // Dedicated Afterschool breakdown — per program, per month.
          // Rendered only when the child has Afterschool history, so
          // workshop-only children keep the previous layout.
          if (data.afterschoolMonths.isNotEmpty) ...[
            _sectionTitle('Situație Afterschool'),
            _afterschoolMonthsBlock(data.afterschoolMonths, bold),
            pw.SizedBox(height: 18),
          ],
          _sectionTitle('Istoric complet activitate'),
          _attendanceTable(data.attendanceRows, bold),
          pw.SizedBox(height: 18),
          // Payments section is hidden entirely when the child has no
          // workshop payment cycles. Afterschool has no payment
          // surface — the previous "Nu există plăți înregistrate"
          // message on a pure Afterschool child was noise.
          if (data.paymentRows.isNotEmpty) ...[
            _sectionTitle('Istoric plăți'),
            _paymentsTable(data.paymentRows, bold),
            pw.SizedBox(height: 18),
          ],
          _sectionTitle('Observații'),
          _observationsBlock(data.observations, bold, italic),
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

  pw.Widget _buildHeader({
    required pw.Context context,
    required ChildActivityReportData data,
    required pw.MemoryImage? logo,
    required pw.Font bold,
  }) {
    final isFirstPage = context.pageNumber == 1;
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
          'Raport activitate – ${data.childInfo.fullName}',
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
              pw.Text(
                'Tales & Tech HUB',
                style: pw.TextStyle(
                  fontSize: 12,
                  font: bold,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Data generării: ${_formatDateTime(data.generatedAt)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'RAPORT ACTIVITATE',
              style: pw.TextStyle(
                fontSize: 18,
                font: bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              data.childInfo.fullName,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey800,
                font: bold,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            height: 1,
            color: PdfColors.grey400,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(
      pw.Context context, ChildActivityReportData data, pw.Font bold) {
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
          pw.Text(
            'Tales & Tech HUB',
            style: pw.TextStyle(
              fontSize: 9,
              font: bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              'Raport activitate copil – ${data.childInfo.fullName}',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Text(
            'Pagina ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ── Section primitives ─────────────────────────────────────────────────────

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

  pw.Widget _childInfoTable(ChildReportChildInfo info, pw.Font bold) {
    final rows = <List<String>>[
      ['Nume copil', info.fullName],
      if (info.birthDate != null)
        ['Data nașterii', _formatDate(info.birthDate!)],
      if (info.age != null) ['Vârstă', '${info.age} ani'],
      ['Părinte', info.parentName ?? '—'],
      ['Telefon părinte', info.parentPhone ?? '—'],
      if (info.parentEmail != null) ['Email părinte', info.parentEmail!],
    ];
    return _twoColumnList(rows, bold);
  }

  pw.Widget _twoColumnList(List<List<String>> rows, pw.Font bold) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(140),
        1: pw.FlexColumnWidth(),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(
                  row[0],
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    font: bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(
                  row[1],
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Unified active-programs block covering workshops + Afterschool.
  /// Each row carries the schedule context; Afterschool rows are
  /// tagged "Afterschool" on the sub-line so the two kinds read
  /// clearly without needing a separate section.
  pw.Widget _activeProgramsBlock({
    required List<ChildReportWorkshopInfo> workshops,
    required List<ChildReportAfterschoolProgramInfo> afterschool,
    required pw.Font bold,
  }) {
    if (workshops.isEmpty && afterschool.isEmpty) {
      return _muted('Nu există programe active.');
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final w in workshops)
          _programRow(title: w.title, subtitle: _workshopScheduleLine(w), bold: bold),
        for (final p in afterschool)
          _programRow(
            title: p.programName,
            subtitle: _afterschoolScheduleLine(p),
            bold: bold,
          ),
      ],
    );
  }

  pw.Widget _programRow({
    required String title,
    required String subtitle,
    required pw.Font bold,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
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
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 10, font: bold),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryBlock(ChildReportSummary s, pw.Font bold) {
    if (!s.hasActivity) {
      return _muted('Nu există activitate înregistrată.');
    }
    final rate = (s.attendanceRate * 100).toStringAsFixed(0);
    final rows = <List<String>>[];
    if (s.hasWorkshopActivity) {
      rows.addAll([
        ['Total ședințe ateliere', '${s.totalSessions}'],
        ['Prezențe ateliere', '${s.presentCount}'],
        ['Absențe ateliere', '${s.absentCount}'],
        if (s.motivatedCount > 0) ['Motivate', '${s.motivatedCount}'],
        ['Rată participare ateliere', '$rate%'],
        ['Total ateliere frecventate', '${s.totalWorkshops}'],
        ['Total cicluri de plată', '${s.totalPaymentCycles}'],
        ['Plăți confirmate', '${s.confirmedPayments}'],
        ['Plăți restante', '${s.overduePayments}'],
      ]);
    }
    if (s.hasAfterschoolActivity) {
      rows.addAll([
        ['Programe Afterschool', '${s.afterschoolProgramsCount}'],
        ['Prezențe Afterschool', '${s.afterschoolPresentCount}'],
        if (s.afterschoolAbsentCount > 0)
          ['Absențe Afterschool', '${s.afterschoolAbsentCount}'],
        if (s.afterschoolUnmarkedCount > 0)
          ['Zile nemarcate Afterschool', '${s.afterschoolUnmarkedCount}'],
        if (s.afterschoolPlannedCount > 0)
          ['Zile planificate rămase', '${s.afterschoolPlannedCount}'],
        if (s.afterschoolLastPresenceDate != null)
          ['Ultima prezență Afterschool',
              _formatDate(s.afterschoolLastPresenceDate!)],
      ]);
    }
    return _twoColumnList(rows, bold);
  }

  /// Per-(program, month) Afterschool attendance table. Grouped by
  /// program with the newest month first inside each group — same
  /// semantics as the UI's child-detail Afterschool panel.
  pw.Widget _afterschoolMonthsBlock(
      List<ChildReportAfterschoolMonth> months, pw.Font bold) {
    if (months.isEmpty) {
      return _muted('Nu există activitate Afterschool înregistrată.');
    }
    // Group by program while preserving the pre-sorted "newest month
    // first" order inside each group.
    final grouped = <String, List<ChildReportAfterschoolMonth>>{};
    final programOrder = <String>[];
    for (final m in months) {
      final key = m.programName;
      final existing = grouped[key];
      if (existing == null) {
        programOrder.add(key);
        grouped[key] = [m];
      } else {
        existing.add(m);
      }
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < programOrder.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 10),
          pw.Text(
            programOrder[i],
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 4),
          _afterschoolMonthTable(grouped[programOrder[i]]!, bold),
        ],
      ],
    );
  }

  pw.Widget _afterschoolMonthTable(
      List<ChildReportAfterschoolMonth> rows, pw.Font bold) {
    final headers = ['Lună', 'Prezențe', 'Prezent', 'Absent', 'Planificate', 'Ultima prezență'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.6),
        1: pw.FixedColumnWidth(55),
        2: pw.FixedColumnWidth(50),
        3: pw.FixedColumnWidth(50),
        4: pw.FixedColumnWidth(72),
        5: pw.FixedColumnWidth(82),
      },
      children: [
        _headerRow(headers, bold),
        for (final r in rows)
          pw.TableRow(
            children: [
              _tdSmall(_monthLabel(r.year, r.month)),
              _tdSmall('${r.present} / ${r.expected}'),
              _tdSmall('${r.present}'),
              _tdSmall('${r.absent}'),
              _tdSmall('${r.plannedFuture}'),
              _tdSmall(r.lastPresenceDate != null
                  ? _formatDate(r.lastPresenceDate!)
                  : '—'),
            ],
          ),
      ],
    );
  }

  pw.Widget _attendanceTable(
      List<ChildReportAttendanceRow> rows, pw.Font bold) {
    if (rows.isEmpty) {
      return _muted('Nu există activitate înregistrată.');
    }
    final headers = ['Data', 'Atelier', 'Trainer', 'Interval', 'Status', 'Observații'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(58),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FixedColumnWidth(70),
        4: pw.FixedColumnWidth(52),
        5: pw.FlexColumnWidth(2.0),
      },
      children: [
        _headerRow(headers, bold),
        for (final row in rows)
          pw.TableRow(
            children: [
              _tdSmall(row.date != null ? _formatDate(row.date!) : '—'),
              _tdSmall(row.workshopTitle),
              _tdSmall(row.trainerName ?? '—'),
              _tdSmall(_timeRange(row.startTime, row.endTime)),
              _tdSmall(_attendanceStatusLabel(row.status)),
              _tdSmall(row.observation == null || row.observation!.isEmpty
                  ? '-'
                  : row.observation!),
            ],
          ),
      ],
    );
  }

  pw.Widget _paymentsTable(
      List<ChildReportPaymentRow> rows, pw.Font bold) {
    if (rows.isEmpty) {
      return _muted('Nu există plăți înregistrate.');
    }

    // Group rows by workshop series (source of truth since migration
    // 20260820). Rows without a series title fall into "Alte cicluri"
    // — legacy paid_advance without safe series mapping.
    final grouped = <String, List<ChildReportPaymentRow>>{};
    for (final r in rows) {
      final key = r.seriesTitle ?? 'Alte cicluri';
      grouped.putIfAbsent(key, () => []).add(r);
    }
    final orderedKeys = grouped.keys.toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < orderedKeys.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 8),
          pw.Text(
            orderedKeys[i],
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 4),
          _paymentsTableForSeries(grouped[orderedKeys[i]]!, bold),
        ],
      ],
    );
  }

  pw.Widget _paymentsTableForSeries(
      List<ChildReportPaymentRow> rows, pw.Font bold) {
    final headers = ['Perioadă', 'Nr. ședințe', 'Status', 'Metodă', 'Data confirmării'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.0),
        1: pw.FixedColumnWidth(60),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FixedColumnWidth(55),
        4: pw.FixedColumnWidth(82),
      },
      children: [
        _headerRow(headers, bold),
        for (final p in rows)
          pw.TableRow(
            children: [
              _tdSmall(_formatPeriod(p.periodStart, p.periodEnd)),
              _tdSmall(p.sessionsCount != null ? '${p.sessionsCount}' : '-'),
              _tdSmall(_paymentStatusLabel(p.status, p.paymentMethod)),
              _tdSmall(_paymentMethodLabel(p.paymentMethod)),
              _tdSmall(p.paidAt != null ? _formatDate(p.paidAt!) : '-'),
            ],
          ),
      ],
    );
  }

  pw.Widget _observationsBlock(
      List<ChildReportObservation> observations,
      pw.Font bold,
      pw.Font italic) {
    if (observations.isEmpty) {
      return _muted('Nu există observații înregistrate.');
    }
    final headers = ['Data', 'Atelier', 'Observație'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(58),
        1: pw.FlexColumnWidth(1.7),
        2: pw.FlexColumnWidth(3.5),
      },
      children: [
        _headerRow(headers, bold),
        for (final o in observations)
          pw.TableRow(
            children: [
              _tdSmall(o.date != null ? _formatDate(o.date!) : '—'),
              _tdSmall(o.workshopTitle),
              _tdSmall(o.text),
            ],
          ),
      ],
    );
  }

  pw.TableRow _headerRow(List<String> headers, pw.Font bold) {
    return pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        for (final h in headers)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: pw.Text(
              h,
              style: pw.TextStyle(fontSize: 9, font: bold),
            ),
          ),
      ],
    );
  }

  pw.Widget _tdSmall(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  pw.Widget _muted(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColors.grey600,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  // ── Formatting helpers ─────────────────────────────────────────────────────

  String _afterschoolScheduleLine(ChildReportAfterschoolProgramInfo p) {
    final parts = <String>['Afterschool'];
    if (p.daysOfWeekLabel.isNotEmpty && p.daysOfWeekLabel != '—') {
      parts.add(p.daysOfWeekLabel);
    }
    final time = _timeRange(p.startTime, p.endTime);
    if (time.isNotEmpty) parts.add(time);
    return parts.join(' · ');
  }

  String _monthLabel(int year, int month) {
    const names = [
      'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
      'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie',
    ];
    return '${names[month - 1]} $year';
  }

  String _workshopScheduleLine(ChildReportWorkshopInfo w) {
    final parts = <String>[];
    if (w.dayOfWeek != null && w.dayOfWeek!.isNotEmpty) parts.add(w.dayOfWeek!);
    final time = _timeRange(w.startTime, w.endTime);
    if (time.isNotEmpty) parts.add(time);
    if (w.trainerName != null) parts.add('Trainer: ${w.trainerName}');
    return parts.join(' · ');
  }

  String _timeRange(String? start, String? end) {
    final s = _trimHm(start);
    final e = _trimHm(end);
    if (s.isEmpty) return '';
    if (e.isEmpty) return s;
    return '$s – $e';
  }

  String _trimHm(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  String _formatDateTime(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year} $hh:$mi';
  }

  String _formatPeriod(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '-';
    if (start != null && end != null) {
      return '${_formatDate(start)} – ${_formatDate(end)}';
    }
    return _formatDate(start ?? end!);
  }

  String _attendanceStatusLabel(String status) {
    switch (status) {
      case 'present':
        return 'Prezent';
      case 'absent':
        return 'Absent';
      case 'motivated':
        return 'Motivat';
      default:
        return status;
    }
  }

  String _paymentStatusLabel(String? status, String? method) {
    final m = _paymentMethodLabel(method);
    final suffix = m == '-' ? '' : ' $m';
    switch (status) {
      case 'paid':
        return 'Plată confirmată$suffix';
      case 'paid_advance':
        return 'Achitat în avans$suffix';
      case 'due':
        return 'Plată neconfirmată';
      case 'overdue':
        return 'Restant';
      case 'cancelled':
        return 'Anulat';
      default:
        return '—';
    }
  }

  String _paymentMethodLabel(String? raw) {
    if (raw == null) return '-';
    final t = raw.trim().toUpperCase();
    if (t.isEmpty) return '-';
    return t;
  }

  // ── Logo ───────────────────────────────────────────────────────────────────

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load(_logoAsset);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
