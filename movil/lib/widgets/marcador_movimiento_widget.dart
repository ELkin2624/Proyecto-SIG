import 'package:flutter/material.dart';
import 'pulse_animation_widget.dart';

class MarcadorMovimientoWidget extends StatelessWidget {
  final String nombre;
  final String hora;
  final Color color;
  final bool animando;

  const MarcadorMovimientoWidget({
    required this.nombre,
    required this.hora,
    required this.color,
    required this.animando,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (animando) PulseAnimation(color: color),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.navigation, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    "EN MOVIMIENTO",
                    style: TextStyle(fontSize: 7, color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    hora,
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 3,
                  )
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ),
      ],
    );
  }
}