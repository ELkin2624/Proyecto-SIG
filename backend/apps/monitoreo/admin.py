# backend/apps/monitoreo/admin.py
from django.contrib import admin
from django.contrib.gis import admin as gis_admin 
from .models import Institucion, Nino, HistorialUbicacion

# Usamos OSMGeoAdmin para tener mapas de OpenStreetMap por defecto
@admin.register(Institucion)
class InstitucionAdmin(gis_admin.GISModelAdmin):
    list_display = ('nombre', 'direccion')
    # Esto define dónde centra el mapa por defecto (Santa Cruz de la Sierra aprox)
    default_lon = -63.18
    default_lat = -17.78
    default_zoom = 12

@admin.register(Nino)
class NinoAdmin(gis_admin.GISModelAdmin):
    list_display = ('nombre', 'tutor', 'institucion', 'activo', 'last_status')
    list_filter = ('institucion', 'activo')
    search_fields = ('nombre', 'tutor__username')

@admin.register(HistorialUbicacion)
class HistorialUbicacionAdmin(gis_admin.GISModelAdmin):
    list_display = ('nino', 'timestamp', 'fuera_de_zona')
    list_filter = ('fuera_de_zona', 'timestamp')
    readonly_fields = ('timestamp',)