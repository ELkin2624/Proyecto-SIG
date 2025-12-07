import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;

      if (code != null && code.isNotEmpty) {
        setState(() => _isProcessing = true);

        // Retornar el código escaneado
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código QR'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(controller: cameraController, onDetect: _handleBarcode),

          // Overlay con guías
          CustomPaint(painter: ScannerOverlay(), child: Container()),

          // Instrucciones
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Coloca el código QR dentro del marco',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter para el overlay del escáner
class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutSize = size.width * 0.7;
    final cutoutLeft = (size.width - cutoutSize) / 2;
    final cutoutTop = (size.height - cutoutSize) / 2;

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutSize, cutoutSize),
          const Radius.circular(12),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawPath(
      backgroundPath,
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawPath(cutoutPath, backgroundPaint);
    canvas.restore();

    // Dibujar el borde del cuadrado
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerSize = 30.0;

    // Esquina superior izquierda
    canvas.drawLine(
      Offset(cutoutLeft, cutoutTop),
      Offset(cutoutLeft + cornerSize, cutoutTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutoutLeft, cutoutTop),
      Offset(cutoutLeft, cutoutTop + cornerSize),
      borderPaint,
    );

    // Esquina superior derecha
    canvas.drawLine(
      Offset(cutoutLeft + cutoutSize, cutoutTop),
      Offset(cutoutLeft + cutoutSize - cornerSize, cutoutTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutoutLeft + cutoutSize, cutoutTop),
      Offset(cutoutLeft + cutoutSize, cutoutTop + cornerSize),
      borderPaint,
    );

    // Esquina inferior izquierda
    canvas.drawLine(
      Offset(cutoutLeft, cutoutTop + cutoutSize),
      Offset(cutoutLeft + cornerSize, cutoutTop + cutoutSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutoutLeft, cutoutTop + cutoutSize),
      Offset(cutoutLeft, cutoutTop + cutoutSize - cornerSize),
      borderPaint,
    );

    // Esquina inferior derecha
    canvas.drawLine(
      Offset(cutoutLeft + cutoutSize, cutoutTop + cutoutSize),
      Offset(cutoutLeft + cutoutSize - cornerSize, cutoutTop + cutoutSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutoutLeft + cutoutSize, cutoutTop + cutoutSize),
      Offset(cutoutLeft + cutoutSize, cutoutTop + cutoutSize - cornerSize),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
