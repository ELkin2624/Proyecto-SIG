# backend/apps/usuarios/models.py
from django.contrib.auth.models import AbstractUser
from django.db import models

class Usuario(AbstractUser):
    telefono = models.CharField(max_length=20, blank=True, help_text="Celular para alertas")
    fcm_token = models.CharField(max_length=255, blank=True, null=True, help_text="Token para notificaciones Push")    
    es_tutor = models.BooleanField(default=True)
    es_admin_institucion = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.username} ({self.first_name} {self.last_name})"