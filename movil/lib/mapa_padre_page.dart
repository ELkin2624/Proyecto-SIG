// movil/lib/mapa_padre_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MapaPadrePage extends StatefulWidget {
  // En el futuro, esto vendrá del Login. Por ahora lo pasamos fijo.
  final String deviceId; 
  const MapaPadrePage({super.key, required this.deviceId});

  @override
  State<MapaPadrePage> createState() => _MapaPadrePageState();
}

class _MapaPadrePageState extends State<MapaPadrePage> {
  // CONFIGURA TU IP AQUÍ
  final String apiUrl = "http://192.168.0.32:8000/api/monitoreo/mapa-padre/";
  
  LatLng? _ubicacionNino;
  List<LatLng> _poligonoKinder = [];
  String _nombreKinder = "Cargando...";
  String _estadoNino = "...";
  Timer? _timer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _obtenerDatos();
    _timer = Timer.periodic(const Duration(seconds: 5), (t) => _obtenerDatos());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _obtenerDatos() async {
    // 1. Recuperamos el Token guardado en el Login
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.get(
        Uri.parse("$apiUrl?device_id=${widget.deviceId}"),
        // 2. Enviamos el Token como pase VIP
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (mounted) { 
          setState(() {
            _estadoNino = data['estado'] ?? "Desconocido";
            
            if (data['ubicacion_actual'] != null) {
               double lat = data['ubicacion_actual']['lat'];
               double lng = data['ubicacion_actual']['lng'];
               _ubicacionNino = LatLng(lat, lng);
            }

            if (data['poligono_kinder'] != null) {
              List<dynamic> puntos = data['poligono_kinder'];
              _poligonoKinder = puntos.map((p) => LatLng(p['lat'], p['lng'])).toList();
              _nombreKinder = data['nombre_kinder'] ?? "Kinder";
            }
          });
        }
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        print("ERROR DE SEGURIDAD: No tienes permiso para ver a este niño.");
      }
    } catch (e) {
      print("Error obteniendo mapa: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Monitoreo: ${widget.deviceId}")),
      body: _ubicacionNino == null 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
              children: [
                // Info Bar
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Lugar: $_nombreKinder", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("Estado: $_estadoNino"),
                        ],
                      ),
                      const Icon(Icons.child_care, size: 30, color: Colors.blue),
                    ],
                  ),
                ),
                // MAPA
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _ubicacionNino!, 
                      initialZoom: 16.0,
                    ),
                    children: [
                      // 1. Capa de Mapa Base
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app_nino',
                      ),
                      
                      // 2. Capa del Polígono (Kinder)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _poligonoKinder,
                            color: Colors.blue.withOpacity(0.3), // El color define el relleno automáticamente
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2,
                            // isFilled: true, <--- ESTA LÍNEA SE ELIMINÓ PORQUE YA NO ES NECESARIA
                          ),
                        ],
                      ),

                      // 3. Capa del Marcador (Niño)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _ubicacionNino!,
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.location_pin, 
                              color: Colors.red, 
                              size: 40
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}