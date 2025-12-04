from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

class RegistrarFcmTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        fcm_token = request.data.get('fcm_token')
        
        if not fcm_token:
            return Response({"error": "Falta el token"}, status=400)

        user = request.user
        user.fcm_token = fcm_token
        user.save()

        print(f"Token FCM actualizado para {user.username}")
        return Response({"status": "Token actualizado correctamente"})