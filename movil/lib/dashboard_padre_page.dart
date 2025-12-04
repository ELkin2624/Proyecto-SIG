// movil/lib/dashboard_padre_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'login_page.dart';

class DashboardPadrePage extends StatefulWidget {
  const DashboardPadrePage({super.key});

  @override
  State<DashboardPadrePage> createState() => _DashboardPadrePageState();
}

class _DashboardPadrePageState extends State<DashboardPadrePage> {
  final MapController _mapController = MapController();
  
  // Elementos visuales del mapa
  List<Marker> _marcadores = [];
  List<Polygon> _geocercas = [];
  List<Polyline> _rutasHistorial = [];

  // Datos crudos para el menú lateral
  List<dynamic> _listaHijosJson = [];
  
  bool _cargando = true;
  bool _mostrandoHistorial = false;
  String _usuarioNombre = "Tutor";
  Timer? _timerActualizacion;

  final List<Color> _colores = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
    _actualizarDatos(); // Primera carga
    _timerActualizacion = Timer.periodic(const Duration(seconds: 10), (t) => _actualizarDatos());
  }

  @override
  void dispose() {
    _timerActualizacion?.cancel();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    // Aquí podrías cargar el nombre real si lo guardaste en el login
    setState(() => _usuarioNombre = "Padre de Familia"); 
  }

  // --- LÓGICA DE CARGA OPTIMIZADA (1 SOLA PETICIÓN) ---
  Future<void> _actualizarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    try {
      // Usamos el nuevo endpoint unificado
      final url = Uri.parse("http://192.168.0.32:8000/api/monitoreo/dashboard-unificado/");
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final List<dynamic> datosHijos = jsonDecode(response.body);
        _procesarDatosMapa(datosHijos); // Transformar JSON a Mapa
        
        if (mounted) {
          setState(() {
            _listaHijosJson = datosHijos;
            _cargando = false;
          });
        }
      }
    } catch (e) {
      print("Error red: $e");
    }
  }

  void _procesarDatosMapa(List<dynamic> hijos) {
    List<Marker> nuevosMarcadores = [];
    List<Polygon> nuevasGeocercas = [];
    int idxColor = 0;

    for (var hijo in hijos) {
      Color color = _colores[idxColor % _colores.length];
      
      // 1. Marcador (Si tiene ubicación)
      if (hijo['ubicacion_actual'] != null) {
        double lat = hijo['ubicacion_actual']['lat'];
        double lng = hijo['ubicacion_actual']['lng'];
        
        nuevosMarcadores.add(
          Marker(
            point: LatLng(lat, lng),
            width: 80,
            height: 80,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  child: Text(hijo['nombre'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Icon(Icons.location_pin, color: color, size: 40),
              ],
            ),
          )
        );
      }

      // 2. Polígono (Si tiene kinder)
      List<dynamic> polyCoords = hijo['poligono_kinder'];
      if (polyCoords.isNotEmpty) {
        List<LatLng> puntos = polyCoords.map((p) => LatLng(p['lat'], p['lng'])).toList();
        nuevasGeocercas.add(
          Polygon(
            points: puntos,
            color: color.withOpacity(0.15),
            borderColor: color,
            borderStrokeWidth: 2,
            label: hijo['nombre_kinder'] ?? "Zona",
            labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
          )
        );
      }
      idxColor++;
    }

    // Actualizamos las listas del mapa
    _marcadores = nuevosMarcadores;
    _geocercas = nuevasGeocercas;
  }

  // --- HISTORIAL (SE MANTIENE IGUAL, ES BAJO DEMANDA) ---
  Future<void> _toggleHistorial() async {
    if (_mostrandoHistorial) {
      setState(() { _rutasHistorial = []; _mostrandoHistorial = false; });
    } else {
      setState(() => _mostrandoHistorial = true);
      int idx = 0;
      for (var hijo in _listaHijosJson) {
        await _cargarHistorialUnico(hijo['device_id'], _colores[idx % _colores.length]);
        idx++;
      }
    }
  }

  Future<void> _cargarHistorialUnico(String deviceId, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final url = Uri.parse("http://192.168.0.32:8000/api/monitoreo/historial/$deviceId/");
    
    try {
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        List<dynamic> raw = jsonDecode(response.body);
        List<LatLng> pts = raw.map((p) => LatLng(p['lat'], p['lng'])).toList();
        
        // Si la lista está vacía o tiene menos de 2 puntos, no dibujamos nada.
        if (pts.isEmpty || pts.length < 2) { return; }

        if (mounted) {
          setState(() {
            _rutasHistorial.add(Polyline(points: pts, color: color.withOpacity(0.7), strokeWidth: 4.0));
          });
        }
      }
    } catch (e) { print(e); }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _centrarEnHijo(dynamic hijo) {
    if (hijo['ubicacion_actual'] != null) {
      double lat = hijo['ubicacion_actual']['lat'];
      double lng = hijo['ubicacion_actual']['lng'];
      _mapController.move(LatLng(lat, lng), 16.0);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Centro de Monitoreo"),
        actions: [
          IconButton(
            icon: Icon(_mostrandoHistorial ? Icons.history_toggle_off : Icons.history),
            onPressed: _toggleHistorial,
            tooltip: "Ver Historial",
          )
        ],
      ),
      drawer: _buildDrawer(),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(
            mapController: _mapController,
            options: const MapOptions(initialCenter: LatLng(-17.78, -63.18), initialZoom: 13),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              PolygonLayer(polygons: _geocercas),
              PolylineLayer(polylines: _rutasHistorial),
              MarkerLayer(markers: _marcadores),
            ],
          ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(_usuarioNombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text("Tutor"),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40)),
            decoration: const BoxDecoration(color: Colors.blue),
          ),
          const Padding(padding: EdgeInsets.all(16), child: Text("MIS HIJOS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          
          ..._listaHijosJson.asMap().entries.map((entry) {
            var hijo = entry.value;
            Color color = _colores[entry.key % _colores.length];
            return ListTile(
              leading: Icon(Icons.face, color: color),
              title: Text(hijo['nombre']),
              subtitle: Text(hijo['last_status'] ?? '...'),
              trailing: const Icon(Icons.gps_fixed),
              onTap: () => _centrarEnHijo(hijo),
            );
          }),
          
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Cerrar Sesión"), onTap: _cerrarSesion),
        ],
      ),
    );
  }
}