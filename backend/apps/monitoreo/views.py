# backend/apps/monitoreo/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.gis.geos import Point
from .models import Nino, HistorialUbicacion
from .serializers import UbicacionUpdateSerializer, NinoSerializer, DashboardHijoSerializer
from django.utils import timezone
from .utils import enviar_alerta_push

from rest_framework import generics, permissions
from rest_framework.permissions import IsAuthenticated

class ReportarUbicacionView(APIView):
    def post(self, request):
        serializer = UbicacionUpdateSerializer(data=request.data)
        if serializer.is_valid():
            device_id = serializer.validated_data['device_id']
            lat = serializer.validated_data['latitud']
            lon = serializer.validated_data['longitud']
            
            # 1. Buscar al niño
            try:
                nino = Nino.objects.get(device_id=device_id)
            except Nino.DoesNotExist:
                return Response({"error": "Niño no encontrado"}, status=status.HTTP_404_NOT_FOUND)

            # 2. Crear el Punto Geográfico
            punto_actual = Point(lon, lat, srid=4326) # OJO: El orden es (Longitud, Latitud)
            
            # 3. VERIFICACIÓN DE GEOCERCA (El corazón del proyecto)
            esta_seguro = True
            mensaje = "Seguro"
            
            if nino.institucion and nino.institucion.area:
                # Preguntamos: ¿El polígono del kinder CONTIENE al punto actual?
                if nino.institucion.area.contains(punto_actual):
                    esta_seguro = True
                    mensaje = "Dentro del Kinder"
                else:
                    esta_seguro = False
                    mensaje = "¡ALERTA! Fuera de zona"
                    # Obtenemos el token del tutor del niño
                    if nino.tutor and nino.tutor.fcm_token:
                        enviar_alerta_push(
                            token_fcm=nino.tutor.fcm_token,
                            titulo="🚨 ALERTA DE SEGURIDAD",
                            cuerpo=f"{nino.nombre} ha salido de la zona segura ({nino.institucion.nombre})."
                        )
            
            # 4. Actualizar estado del niño
            nino.ultima_ubicacion = punto_actual
            nino.last_status = mensaje
            nino.save()
            
            # 5. Guardar historial
            HistorialUbicacion.objects.create(
                nino=nino,
                ubicacion=punto_actual,
                fuera_de_zona=not esta_seguro
            )
            
            return Response({
                "status": "success",
                "seguro": esta_seguro,
                "mensaje": mensaje
            })
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
class DatosMapaPadreView(APIView):
    # GET /api/monitoreo/mapa-padre/?device_id=android123
    permission_classes = [IsAuthenticated]

    def get(self, request):
        device_id = request.query_params.get('device_id')
        
        try:
            # validar que el nino pertenece al padre logueado
            nino = Nino.objects.get(device_id=device_id, tutor=request.user)
        except Nino.DoesNotExist:
            return Response({"error": "No autorizado o niño no encontrado"}, status=403)
        
        data = {
            "nombre_nino": nino.nombre,
            "ultima_actualizacion": nino.ultima_actualizacion,
            "estado": nino.last_status,
            
            # 1. Ubicación del Niño
            "ubicacion_actual": {
                "lat": nino.ultima_ubicacion.y if nino.ultima_ubicacion else 0,
                "lng": nino.ultima_ubicacion.x if nino.ultima_ubicacion else 0,
            },
            
            # 2. Polígono del Kinder (La Geocerca)
            "poligono_kinder": [] 
        }

        # Si tiene kinder asignado y dibujo, extraemos las coordenadas
        if nino.institucion and nino.institucion.area:
            # PostGIS guarda: (Lon, Lat). Flutter usa: (Lat, Lon). Invertimos aquí:
            coords = nino.institucion.area.coords[0] # [0] es el anillo exterior
            poligono = [{"lat": p[1], "lng": p[0]} for p in coords]
            data["poligono_kinder"] = poligono
            data["nombre_kinder"] = nino.institucion.nombre

        return Response(data)
    
# 1. LISTA DE HIJOS (Dashboard Principal)
# Solo devuelve los niños que pertenecen al padre logueado
class MisHijosListView(generics.ListAPIView):
    serializer_class = NinoSerializer
    permission_classes = [permissions.IsAuthenticated] 

    def get_queryset(self):
        # FILTRO MÁGICO: "Trae los niños cuyo tutor sea el usuario actual"
        return Nino.objects.filter(tutor=self.request.user)

# 2. HISTORIAL DE RUTAS (Para dibujar la línea)
class HistorialRutaView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, device_id):
        # Verificar que el niño sea de este padre (Seguridad)
        try:
            nino = Nino.objects.get(device_id=device_id, tutor=request.user)
        except Nino.DoesNotExist:
            return Response({"error": "No autorizado o niño no existe"}, status=403)
            
        # Obtener los últimos 100 puntos (o filtrar por fecha)
        puntos = HistorialUbicacion.objects.filter(nino=nino).order_by('-timestamp')[:100]
        
        # Formato para Flutter (Lista de Lat/Lng)
        ruta = [{"lat": p.ubicacion.y, "lng": p.ubicacion.x, "fecha": p.timestamp} for p in puntos]
        
        return Response(ruta)
    
class DashboardPadreUnificadoView(generics.ListAPIView):
    serializer_class = DashboardHijoSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Nino.objects.filter(tutor=self.request.user)