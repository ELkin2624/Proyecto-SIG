import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class PuntoHistorial {
  final LatLng latLng;
  final String timestamp;
  final int indice;
  final int totalPuntos;

  PuntoHistorial({
    required this.latLng,
    required this.timestamp,
    required this.indice,
    required this.totalPuntos,
  });
}

class RutaHistorial {
  final List<PuntoHistorial> puntos;
  final Color color;
  final double distanciaTotal;
  final Duration tiempoTotal;

  RutaHistorial({
    required this.puntos,
    required this.color,
    required this.distanciaTotal,
    required this.tiempoTotal,
  });
}