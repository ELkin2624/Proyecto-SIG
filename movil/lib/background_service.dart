// movil/lib/background_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // debugPrint
import 'config/api_config.dart';

// Inicializa/Configura el servicio (llamar desde main() antes de startService si aún no lo hiciste)
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'Seguridad en Segundo Plano',
    description: 'Este canal mantiene vivo el rastreo',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // inicia manualmente desde la UI del niño
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'SafeKid Activo',
      initialNotificationContent: 'Protegiendo a tu hijo...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      // Para iOS necesitarás otra implementación de background location
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

/// Required for iOS background execution placeholder
@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  // iOS background handling needs different approach (significant location changes, etc.)
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // IMPORTANTE: Esta función corre en un isolate distinto al de la UI.
  DartPluginRegistrant.ensureInitialized();

  // Timer reference para poder cancelarlo al recibir "stopService"
  Timer? periodicTimer;

  // Leer ID y backend desde SharedPreferences (guardados por la app foreground)
  final prefs = await SharedPreferences.getInstance();
  String deviceId = prefs.getString('child_device_id') ?? "desconocido";
  final backendBase = "${ApiConfig.baseUrl}/api/monitoreo"; 
  final reportUrl = "$backendBase/reportar/";
  final estadoUrl = "$backendBase/estado/$deviceId/";

  if (deviceId == "desconocido" || deviceId.isEmpty) {
    debugPrint('[BackgroundService] device_id desconocido, deteniendo servicio');
    // Avisa y detén
    try {
      await prefs.setBool('service_active', false);
    } catch (_) {}
    service.stopSelf();
    return;
  }

  // Helper para actualizar notificación (Android)
  Future<void> updateNotification(String title, String body) async {
    try {
      if (service is ServiceInstance) {
        service.invoke('update', {"title": title, "content": body});
      }
    } catch (_) {}
  }

  // Función principal que intenta rastrear y reportar una vez
  Future<void> doReportOnce() async {
    try {
      // 1) Consultar al backend si debe rastrear (la API puede devolver activo: true/false)
      final estadoResp = await http
          .get(Uri.parse("$backendBase/estado/$deviceId/"))
          .timeout(const Duration(seconds: 8));
      if (estadoResp.statusCode != 200) {
        debugPrint('[BackgroundService] estadoResp status ${estadoResp.statusCode}');
        return;
      }

      final estadoJson = jsonDecode(estadoResp.body);
      final bool activo = estadoJson['activo'] ?? false;

      if (!activo) {
        // No rastrear ahora
        debugPrint('[BackgroundService] Rastreo pausado por el padre (activo=false)');
        await updateNotification('SafeKid', 'Rastreo pausado por el padre');
        return;
      }

      // 2) Obtener ubicación con timeout y manejo de errores
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('[BackgroundService] error obteniendo posición: $e');
        return;
      }

      // 3) Otros datos (batería, conexión)
      int bateria = await Battery().batteryLevel;
      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());
      String tipoConexion = "OFFLINE";
      if (connectivityResult.contains(ConnectivityResult.mobile)) {
        tipoConexion = "DATOS";
      } else if (connectivityResult.contains(ConnectivityResult.wifi)) {
        tipoConexion = "WIFI";
      }

      // 4) Enviar al backend
      final payload = {
        "device_id": deviceId,
        "latitud": position.latitude,
        "longitud": position.longitude,
        "timestamp": DateTime.now().toIso8601String(),
        "bateria": bateria,
        "conexion": tipoConexion,
      };

      try {
        final resp = await http
            .post(Uri.parse(reportUrl),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode(payload))
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          debugPrint('[BackgroundService] Reporte enviado correctamente');
          await updateNotification('SafeKid Activo', 'Ubicación enviada');
        } else {
          debugPrint('[BackgroundService] Error al reportar: ${resp.statusCode}');
          await updateNotification('SafeKid', 'Error al reportar (${resp.statusCode})');
        }
      } catch (e) {
        debugPrint('[BackgroundService] Excepción al postear: $e');
        await updateNotification('SafeKid', 'Sin conexión al enviar ubicación');
      }
    } catch (e) {
      debugPrint('[BackgroundService] Error general en doReportOnce: $e');
    }
  }

  // Manejar comando remoto de detener servicio (invocado desde la app parent al backend -> backend notifica al device)
  service.on('stopService').listen((event) async {
    debugPrint('[BackgroundService] stopService recibido desde invoke');
    try {
      await prefs.setBool('service_active', false);
    } catch (_) {}
    // cancelar timer y detener el servicio
    periodicTimer?.cancel();
    await updateNotification('SafeKid', 'Protección desactivada');
    service.stopSelf();
  });

  // También permitir detener con evento general 'stop' (según implementación)
  service.on('stop').listen((event) async {
    debugPrint('[BackgroundService] stop recibido');
    periodicTimer?.cancel();
    try {
      await prefs.setBool('service_active', false);
    } catch (_) {}
    service.stopSelf();
  });

  // Opcional: manejar update de notificación
  service.on('update').listen((event) {
    // puedes leer payload y actualizar la notificación nativa si lo implementas
  });

  // Iniciar el Timer periódico y guardarlo en periodicTimer para poder cancelarlo
  const baseIntervalSeconds = 15;
  int failCount = 0;
  periodicTimer = Timer.periodic(const Duration(seconds: baseIntervalSeconds), (timer) async {
    // Si el servicio fue detenido por otro mecanismo, terminamos
    await prefs.reload();
    final bool? flagActive = prefs.getBool('service_active');
    if (flagActive == false) {
      debugPrint('[BackgroundService] service_active flag false -> deteniendo');
      timer.cancel();
      service.stopSelf();
      return;
    }

    try {
      await doReportOnce();
      failCount = 0; // resetear contador de fallos tras éxito o intento
    } catch (e) {
      failCount++;
      debugPrint('[BackgroundService] fallo en iteración: $e (failCount=$failCount)');
      // Si hay muchos fallos consecutivos, hacer backoff y/o detener
      if (failCount >= 6) {
        debugPrint('[BackgroundService] Demasiados fallos, esperando más tiempo antes de reintentar');
        // reiniciar timer con más retraso (simplemente cancelar y crear uno nuevo)
        timer.cancel();
        periodicTimer = Timer.periodic(const Duration(seconds: baseIntervalSeconds * 4), (t) async {
          final bool? fActive = prefs.getBool('service_active');
          if (fActive == false) {
            t.cancel();
            service.stopSelf();
            return;
          }
          await doReportOnce();
        });
      }
    }
  });

  // Notificar que el service arrancó
  await updateNotification('SafeKid Activo', 'Servicio corriendo en segundo plano');
}
