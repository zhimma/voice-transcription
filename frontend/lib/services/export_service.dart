import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/task.dart';

class ExportService {
  Future<void> exportTxt(Task task) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出 TXT',
      fileName: '${task.fileName}.txt',
    );
    if (path == null) return;
    final text = task.transcription?.fullText ?? '';
    await File(path).writeAsString(text, flush: true);
  }

  Future<void> exportJson(Task task) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出 JSON',
      fileName: '${task.fileName}.json',
    );
    if (path == null) return;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(task.toJson());
    await File(path).writeAsString(jsonStr, flush: true);
  }

  Future<void> exportPdf(Task task) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出 PDF',
      fileName: '${task.fileName}.pdf',
    );
    if (path == null) return;
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansSCRegular();

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font),
        build: (context) {
          return [
            pw.Text('转写结果', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('文件名: ${task.fileName}'),
            pw.Text('模型: ${task.model}'),
            pw.SizedBox(height: 12),
            pw.Text(task.transcription?.fullText ?? ''),
            pw.SizedBox(height: 16),
            pw.Text('摘要', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(task.summary?.medium ?? '暂无摘要'),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
