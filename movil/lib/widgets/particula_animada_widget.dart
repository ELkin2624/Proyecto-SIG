import 'package:flutter/material.dart';

class ParticulaAnimada extends StatefulWidget {
  final Color color;
  const ParticulaAnimada({required this.color});

  @override
  State<ParticulaAnimada> createState() => _ParticulaAnimadaState();
}

class _ParticulaAnimadaState extends State<ParticulaAnimada> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 12 + (8 * _controller.value),
          height: 12 + (8 * _controller.value),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.6 * (1 - _controller.value)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ],
          ),
        );
      },
    );
  }
}