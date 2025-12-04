# backend/apps/monitoreo/urls.py
from django.urls import path
from .views import (ReportarUbicacionView, DatosMapaPadreView,
    MisHijosListView, HistorialRutaView, DashboardPadreUnificadoView
)

urlpatterns = [
    path('reportar/', ReportarUbicacionView.as_view(), name='reportar-ubicacion'),
    path('mapa-padre/', DatosMapaPadreView.as_view(), name='mapa-padre'),
    path('mis-hijos/', MisHijosListView.as_view()),
    path('historial/<str:device_id>/', HistorialRutaView.as_view()),
    path('dashboard-unificado/', DashboardPadreUnificadoView.as_view()),
]