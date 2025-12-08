# backend/apps/monitoreo/serializers.py
from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Nino, Institucion, HistorialUbicacion

class InstitucionSerializer(GeoFeatureModelSerializer):
    """
    Serializer para Instituciones que maneja automáticamente campos GeoJSON
    """
    class Meta:
        model = Institucion
        geo_field = 'area'  # Campo geográfico que se serializará como geometry
        fields = ['id', 'nombre', 'direccion', 'area']

class NinoSerializer(serializers.ModelSerializer):
    institucion_nombre = serializers.CharField(source='institucion.nombre', read_only=True)
    tutor_nombre = serializers.CharField(source='tutor.username', read_only=True)

    class Meta:
        model = Nino
        fields = ['id', 'nombre', 'device_id', 'activo', 'last_status', 'tutor', 'tutor_nombre', 'institucion', 'institucion_nombre', 'ultima_ubicacion', 'ultima_actualizacion']

class UbicacionUpdateSerializer(serializers.Serializer):
    # Este no es un modelo, es solo para validar lo que manda el celular
    device_id = serializers.CharField()
    latitud = serializers.FloatField()
    longitud = serializers.FloatField()
    fcm_token = serializers.CharField(required=False, allow_blank=True)
    timestamp = serializers.DateTimeField(required=False)
    bateria = serializers.IntegerField(required=False, allow_null=True)
    conexion = serializers.CharField(required=False, allow_blank=True)
    es_sos = serializers.BooleanField(required=False, default=False)
    
class DashboardHijoSerializer(serializers.ModelSerializer):
    ubicacion_actual = serializers.SerializerMethodField()
    poligono_kinder = serializers.SerializerMethodField()
    bateria = serializers.SerializerMethodField()
    nombre_kinder = serializers.ReadOnlyField(source='institucion.nombre')
    info_dispositivo = serializers.SerializerMethodField()

    class Meta:
        model = Nino
        fields = [
            'device_id', 'nombre', 'last_status', 'estado_alerta', 'ultima_actualizacion',
            'ubicacion_actual', 'poligono_kinder', 'nombre_kinder', 'bateria',
            'info_dispositivo', 'monitoreo_activo'
        ]

    def get_bateria(self, obj):
        # Intentamos obtener la última entrada de historial para este niño
        try:
            ultima = HistorialUbicacion.objects.filter(nino=obj).order_by('-timestamp').first()
            return ultima.bateria if ultima and ultima.bateria is not None else None
        except Exception:
            return None
        
    def get_info_dispositivo(self, obj):
        # Buscamos el último historial para sacar batería y conexión
        ultimo = HistorialUbicacion.objects.filter(nino=obj).order_by('-timestamp').first()
        if ultimo:
            return {
                "bateria": ultimo.bateria,
                "conexion": ultimo.conexion
            }
        return {"bateria": 0, "conexion": "OFFLINE"}

    def get_ubicacion_actual(self, obj):
        if obj.ultima_ubicacion:
            return {
                "lat": obj.ultima_ubicacion.y,
                "lng": obj.ultima_ubicacion.x
            }
        return None

    def get_poligono_kinder(self, obj):
        if obj.institucion and obj.institucion.area:
            coords = obj.institucion.area.coords[0]
            return [{"lat": p[1], "lng": p[0]} for p in coords]
        return []

