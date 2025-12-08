# backend/apps/monitoreo/urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ReportarUbicacionView,
    DatosMapaPadreView,
    MisHijosListView,
    HistorialRutaView,
    DashboardPadreUnificadoView,
    DashboardPadreUnificadoView,
    InstitucionViewSet,
    ConfirmarAlertaView,
    EstadoMonitoreoView,
    CambiarEstadoMonitoreoView,
    ActivarMonitoreoDispositivoView
    NinoViewSet,
    InstitucionViewSet,
    NinosPorInstitucionView
)

# ========================================
# ROUTER PARA VIEWSETS (CRUD AUTOMÁTICO)
# ========================================
router = DefaultRouter()
router.register(r'ninos', NinoViewSet, basename='nino')  # CRUD Niños (Admin)
router.register(r'instituciones', InstitucionViewSet, basename='institucion')  # CRUD Instituciones

# ========================================
# URLS DE MONITOREO
# ========================================
urlpatterns = [
    # Endpoints especiales (no CRUD)
    path('reportar/', ReportarUbicacionView.as_view(), name='reportar-ubicacion'),
    path('mapa-padre/', DatosMapaPadreView.as_view(), name='mapa-padre'),
    path('mis-hijos/', MisHijosListView.as_view()),
    path('historial/<str:device_id>/', HistorialRutaView.as_view()),
    path('dashboard-unificado/', DashboardPadreUnificadoView.as_view()),
    path('confirmar-alerta/', ConfirmarAlertaView.as_view(), name='confirmar-alerta'),

    path('estado/<str:device_id>/', EstadoMonitoreoView.as_view()),
    path('cambiar-estado/', CambiarEstadoMonitoreoView.as_view()),
    path('activar-dispositivo/', ActivarMonitoreoDispositivoView.as_view()),
    path('instituciones/<int:institucion_id>/ninos/', NinosPorInstitucionView.as_view(), name='ninos-por-institucion'),
    # Incluir rutas del router (CRUD instituciones)
    path('', include(router.urls)),
]
