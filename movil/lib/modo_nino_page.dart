// movil/lib/modo_nino_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/api_config.dart';
import 'package:flutter/services.dart'; // para HapticFeedback
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _rastreando = false; // Timer local (foreground)
  Timer? _timer;
  String _miToken = "...";
  int _intervaloSegundos = 15; // Intervalo local inicial
  bool _servicioFondoActivo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configurarTodo();
    _checkBackgroundService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Se ejecuta al cambiar el estado de la app (ej. volver desde background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // refrescar el estado del servicio al volver a la app
      _checkBackgroundService();
    }
  }

  // Comprueba si el servicio de fondo está corriendo y actualiza UI/flags
  Future<void> _checkBackgroundService() async {
    final service = FlutterBackgroundService();
    try {
      var isRunning = await service.isRunning();
      if (!mounted) return;
      setState(() {
        _servicioFondoActivo = isRunning;
        if (_servicioFondoActivo) {
          _estado = "Protección Activa (24/7)";
          _colorEstado = Colors.green;
          // Si el servicio está activo, cancelar timer local para evitar duplicados
          if (_rastreando) {
            _timer?.cancel();
            _rastreando = false;
          }
        } else {
          // Si no hay servicio, dejamos estado tal cual (o podríamos iniciar rastreo local)
          // _estado = "Listo";
          // _colorEstado = Colors.grey;
        }
      });
    } catch (e) {
      // Ignorar fallo leve; opcionalmente loggear en modo debug
      // print('checkBackgroundService error: $e');
    }
  }

  Future<void> _configurarTodo() async {
    // 1) Comprobar servicio de ubicación
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

    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    String tipoConexion = "OFFLINE";

    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      tipoConexion = "DATOS";
    } else if (connectivityResult.contains(ConnectivityResult.wifi)) {
      tipoConexion = "WIFI";
    }

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
        "conexion": tipoConexion,
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
                // Está fuera del área: intervalos cortos (10s) para seguimiento más rápido
                _cambiarIntervalo(10); // 10 por ahora, ajustar en producción
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

    // Si está rastreando (timer local), reinicia el timer con el nuevo intervalo
    if (_rastreando) {
      _timer?.cancel();
      _timer = Timer.periodic(
        Duration(seconds: _intervaloSegundos),
        (t) => _reportarUbicacion(),
      );
    }
  }

  // Mantengo la posibilidad de tener rastreo local (foreground) solo si no hay servicio de fondo.
  // En la app del niño el rastreo local solo puede iniciarse si no hay servicio de fondo activo.
  void _toggleRastreo() {
    if (_servicioFondoActivo) {
      // evitar que el niño inicie/pare rastreo si el servicio de fondo está activo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede cambiar el rastreo desde aquí.')),
      );
      return;
    }

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

            // Botón para activar PROTECCIÓN (solo permite activar; si ya está activo queda deshabilitado)
            ElevatedButton.icon(
              onPressed: _servicioFondoActivo ? null : _activarServicioFondo,
              icon: Icon(_servicioFondoActivo ? Icons.lock : Icons.play_circle),
              label: Text(
                _servicioFondoActivo
                    ? "PROTECCIÓN ACTIVA"
                    : "ACTIVAR PROTECCIÓN",
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),

            const SizedBox(height: 12),

            // (Opcional) Botón para iniciar rastreo local SOLO si no hay servicio de fondo
            // Puedes ocultarlo en producción si no quieres que exista rastreo local en la app del niño.
            ElevatedButton(
              onPressed:
                  _servicioFondoActivo ? null : _toggleRastreo, // bloqueado si service activo
              child: Text(_rastreando ? "DETENER RASTREO LOCAL" : "INICIAR RASTREO LOCAL"),
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

  // Activa únicamente el servicio de fondo; NO detiene el servicio (solo el padre podrá hacerlo).
  Future<void> _activarServicioFondo() async {
    final prefs = await SharedPreferences.getInstance();
    final service = FlutterBackgroundService();

    try {
      try {
        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/api/monitoreo/activar-dispositivo/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "device_id": widget.deviceId,
            "activo": true // <--- ENCENDER
          }),
        );
        print("✅ Base de datos actualizada: ACTIVO");
      } catch (e) {
        print("⚠️ Error avisando al servidor: $e");
        // Opcional: Mostrar error, pero seguimos intentando activar localmente
      }

      var isRunning = await service.isRunning();

      if (!isRunning) {
        // Guardar ID y flag para que el servicio lo lea
        await prefs.setString('child_device_id', widget.deviceId);
        await prefs.setBool('service_active', true);
        await prefs.reload();
        
        await service.startService();

        // Pequeña espera y verificación
        await Future.delayed(const Duration(milliseconds: 500));
        var nowRunning = await service.isRunning();

        if (!mounted) return;
        if (nowRunning) {
          // Si el servicio se arrancó, cancelar timer local para evitar duplicados
          if (_rastreando) {
            _timer?.cancel();
            _rastreando = false;
          }
          setState(() {
            _servicioFondoActivo = true;
            _estado = "Protección Activa (24/7)";
            _colorEstado = Colors.green;
          });
          HapticFeedback.mediumImpact();
        } else {
          // No arrancó correctamente
          setState(() {
            _estado = "No se pudo iniciar servicio fondo";
            _colorEstado = Colors.orange;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No se pudo iniciar el servicio de fondo. Revisa permisos o restricciones del dispositivo.'),
            ),
          );
        }
      } else {
        // Si ya está corriendo, solo actualizamos estado visual
        if (!mounted) return;
        setState(() {
          _servicioFondoActivo = true;
          _estado = "Protección Activa (24/7)";
          _colorEstado = Colors.green;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'La protección ya está activa. Solo el padre puede detener el rastreo.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = "Error servicio fondo";
        _colorEstado = Colors.orange;
      });
    }
  }
}
