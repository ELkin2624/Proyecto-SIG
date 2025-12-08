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
)

# Router para ViewSets (CRUD automático)
router = DefaultRouter()
router.register(r'instituciones', InstitucionViewSet, basename='institucion')

urlpatterns = [
    path('reportar/', ReportarUbicacionView.as_view(), name='reportar-ubicacion'),
    path('mapa-padre/', DatosMapaPadreView.as_view(), name='mapa-padre'),
    path('mis-hijos/', MisHijosListView.as_view()),
    path('historial/<str:device_id>/', HistorialRutaView.as_view()),
    path('dashboard-unificado/', DashboardPadreUnificadoView.as_view()),
    path('confirmar-alerta/', ConfirmarAlertaView.as_view(), name='confirmar-alerta'),

    path('estado/<str:device_id>/', EstadoMonitoreoView.as_view()),
    path('cambiar-estado/', CambiarEstadoMonitoreoView.as_view()),
    path('activar-dispositivo/', ActivarMonitoreoDispositivoView.as_view()),
    # Incluir rutas del router (CRUD instituciones)
    path('', include(router.urls)),
]
