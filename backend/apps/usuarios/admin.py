# backend/apps/usuarios/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Usuario

# Registramos tu usuario con la clase base UserAdmin para que maneje las contraseñas bien
@admin.register(Usuario)
class UsuarioAdmin(UserAdmin):
    # Agregamos tus campos personalizados al panel
    fieldsets = UserAdmin.fieldsets + (
        ('Datos Adicionales', {'fields': ('telefono', 'fcm_token', 'es_tutor', 'es_admin_institucion')}),
    )
    list_display = ('username', 'email', 'first_name', 'telefono', 'es_tutor')