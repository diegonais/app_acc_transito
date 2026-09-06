import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

class ReportPdfShareService {
  const ReportPdfShareService();

  Future<ShareResult> sharePdf({
    required Uint8List bytes,
    required String fileName,
    String? subject,
    String? text,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'application/pdf',
          ),
        ],
        fileNameOverrides: [fileName],
        subject: subject,
        text: text,
      ),
    );
  }
}
