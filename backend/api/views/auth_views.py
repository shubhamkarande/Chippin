"""
Authentication views for Chippin API.
"""
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from api.serializers import UserSerializer
from api.models import User


class VerifyTokenView(APIView):
    """
    Verify Firebase token and return user info.
    Creates user if doesn't exist.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        """
        Verify Firebase ID token.

        Request body:
        {
            "token": "firebase_id_token",
            "display_name": "optional_display_name"
        }
        """
        from api.authentication import get_firebase_app
        from firebase_admin import auth as firebase_auth

        token = request.data.get('token')
        if not token:
            return Response(
                {'error': 'Token is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Verify the Firebase token
            get_firebase_app()
            decoded_token = firebase_auth.verify_id_token(token)
            uid = decoded_token.get('uid')

            if not uid:
                return Response(
                    {'error': 'Invalid token'},
                    status=status.HTTP_401_UNAUTHORIZED
                )

            # Get or create user
            user, created = User.objects.get_or_create(
                firebase_uid=uid,
                defaults={
                    'username': uid,
                    'email': decoded_token.get('email', ''),
                    'display_name': request.data.get('display_name') or decoded_token.get('name', ''),
                }
            )

            # Update user info
            if not created:
                update_fields = []
                if decoded_token.get('email') and user.email != decoded_token['email']:
                    user.email = decoded_token['email']
                    update_fields.append('email')
                if request.data.get('display_name'):
                    user.display_name = request.data['display_name']
                    update_fields.append('display_name')
                if update_fields:
                    user.save(update_fields=update_fields)

            serializer = UserSerializer(user)
            return Response({
                'user': serializer.data,
                'created': created
            }, status=status.HTTP_200_OK)

        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_401_UNAUTHORIZED
            )


class GuestLoginView(APIView):
    """
    Create a guest user account for offline-first usage.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        """
        Create a guest user.

        Request body:
        {
            "device_id": "unique_device_identifier",
            "display_name": "optional_name"
        }
        """
        import uuid

        device_id = request.data.get('device_id')
        if not device_id:
            return Response(
                {'error': 'Device ID is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create or get guest user
        guest_username = f"guest_{device_id[:32]}"
        user, created = User.objects.get_or_create(
            username=guest_username,
            defaults={
                'display_name': request.data.get('display_name', 'Guest User'),
                'is_guest': True,
            }
        )

        serializer = UserSerializer(user)
        return Response({
            'user': serializer.data,
            'created': created,
            'guest_token': str(user.id)  # Simple token for guest users
        }, status=status.HTTP_200_OK)


class CurrentUserView(APIView):
    """
    Get current authenticated user info.
    """

    def get(self, request):
        """Get current user."""
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    def patch(self, request):
        """Update current user."""
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
