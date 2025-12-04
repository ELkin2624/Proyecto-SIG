# backend/apps/monitoreo/urls.py
from django.urls import path
from .views import RegistrarFcmTokenView

urlpatterns = [
    path('registrar-token/', RegistrarFcmTokenView.as_view(), name='registrar-token'),
]