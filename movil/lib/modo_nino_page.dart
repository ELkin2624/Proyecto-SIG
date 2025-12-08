// movil/lib/modo_nino_page.darteso
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:battery_plus/battery_plus.dart';
import 'config/api_config.dart';
import 'package:flutter/services.dart'; // para HapticFeedback

class SafeKidHome extends StatefulWidget {
  final String deviceId;
  const SafeKidHome({super.key, required this.deviceId});

  @override
  State<SafeKidHome> createState() => _SafeKidHomeState();
}

class _SafeKidHomeState extends State<SafeKidHome> with WidgetsBindingObserver {
  // CONFIGURA TU IP AQUÍ
  final String backendUrl = "${ApiConfig.baseUrl}/api/monitoreo/reportar/";

  String _estado = "Inicializando...";
  Color _colorEstado = Colors.grey;
  bool _rastreando = false;
  Timer? _timer;
  String _miToken = "...";
  int _intervaloSegundos = 15; // Intervalo inicial de 15 segundos para enviar la ubicación actual
  // en modo seguro =15 segundos, fuera de zona =5 segundos
  // _cambiarIntervalo() hace eso

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configurarTodo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _configurarTodo() async {
    // 1) Comprobar servicio
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _estado = "Activa el GPS";
          _colorEstado = Colors.orange;
        });
      }
    }

    // 2) Pedir permisos con Geolocator
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _estado = "Permiso de ubicación requerido";
          _colorEstado = Colors.orange;
        });
      }
      return;
    }

    // 3) FCM token
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    String? token = await messaging.getToken();
    if (mounted) {
      setState(() {
        _miToken = token ?? "Error";
        _estado = "Listo";
        _colorEstado = Colors.green;
      });
    }
  }

  Future<void> _reportarUbicacion() async {
    var battery = Battery();
    int nivelBateria = await battery.batteryLevel;

    if (!mounted) return;
    setState(() {
      _estado = "Enviando...";
      _colorEstado = Colors.blue;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      Map<String, dynamic> data = {
        "device_id": widget.deviceId,
        "latitud": position.latitude,
        "longitud": position.longitude,
        "fcm_token": _miToken,
        "timestamp": DateTime.now().toIso8601String(),
        "bateria": nivelBateria,
      };

      final response = await http
          .post(
            Uri.parse(backendUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final r = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _estado = r['mensaje'] ?? "Reportado";
            final seguro = r['seguro'];
            if (seguro is bool) {
              _colorEstado = seguro ? Colors.green : Colors.red;
              if (seguro) {
                // Está dentro del área: intervalos normales (15s)
                _cambiarIntervalo(15);
              } else {
                // Está fuera del área: intervalos cortos (10s) para seguimiento rápido
                _cambiarIntervalo(10); // 10 por ahora, manda mucha notificaciones
              }
            } else {
              _colorEstado = Colors.orange;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _estado = "Error servidor ${response.statusCode}";
            _colorEstado = Colors.orange;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = "Error conexión";
          _colorEstado = Colors.red;
        });
      }
    }
  }

  void _cambiarIntervalo(int nuevoIntervalo) {
    if (_intervaloSegundos == nuevoIntervalo) return; // No cambiar si es igual

    setState(() {
      _intervaloSegundos = nuevoIntervalo;
    });

    // Si está rastreando, reinicia el timer con el nuevo intervalo
    if (_rastreando) {
      _timer?.cancel();
      _timer = Timer.periodic(
        Duration(seconds: _intervaloSegundos),
        (t) => _reportarUbicacion(),
      );
    }
  }

  void _toggleRastreo() {
    if (_rastreando) {
      _timer?.cancel();
      setState(() {
        _rastreando = false;
        _estado = "Detenido";
        _colorEstado = Colors.grey;
      });
    } else {
      // Recomiendo >=15s en producción
      _timer = Timer.periodic(
        Duration(seconds: _intervaloSegundos),
        (t) => _reportarUbicacion(),
      );
      setState(() {
        _rastreando = true;
        _estado = "Rastreando...";
        _colorEstado = Colors.blue;
      });
      _reportarUbicacion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _colorEstado == Colors.red ? Icons.warning : Icons.security;
    return Scaffold(
      appBar: AppBar(title: const Text("Modo Niño")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 100, color: _colorEstado),
            const SizedBox(height: 10),
            Text(_estado, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              "Device ID: ${widget.deviceId}",
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleRastreo,
              child: Text(_rastreando ? "DETENER" : "ACTIVAR"),
            ),
            const SizedBox(height: 20),
            // Botón SOS
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: InkWell(
                onLongPress: _enviarSOS,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.sos, size: 50, color: Colors.white),
                    Text(
                      "MANTÉN PARA\nAYUDA",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarSOS() async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _estado = "Enviando SOS...";
      _colorEstado = Colors.red;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      var battery = Battery();
      int nivelBateria = await battery.batteryLevel;

      Map<String, dynamic> data = {
        "device_id": widget.deviceId,
        "latitud": position.latitude,
        "longitud": position.longitude,
        "fcm_token": _miToken,
        "timestamp": DateTime.now().toIso8601String(),
        "bateria": nivelBateria,
        "es_sos": true,
      };

      final response = await http
          .post(
            Uri.parse(backendUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final r = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _estado = r['mensaje'] ?? "SOS Enviado";
            _colorEstado = Colors.red;
          });
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          HapticFeedback.heavyImpact();
        }
      } else {
        if (mounted) {
          setState(() {
            _estado = "Error servidor ${response.statusCode}";
            _colorEstado = Colors.orange;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = "Error conexión SOS";
          _colorEstado = Colors.red;
        });
      }
    }
  }
}
