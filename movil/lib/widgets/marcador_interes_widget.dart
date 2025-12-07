
import 'package:flutter/material.dart';

class MarcadorInteresWidget extends StatelessWidget {
  final String hora;
  final Color color;

  const MarcadorInteresWidget({
    required this.hora,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle, size: 10, color: color),
              const SizedBox(width: 3),
              Text(
                hora,
                style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}
