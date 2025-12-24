"""
Firebase Authentication for Django REST Framework.
"""
from rest_framework import authentication, exceptions
from django.conf import settings
import firebase_admin
from firebase_admin import auth as firebase_auth, credentials


# Initialize Firebase Admin SDK
_firebase_app = None


def get_firebase_app():
    """Get or initialize Firebase Admin app."""
    global _firebase_app
    if _firebase_app is None:
        try:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
            _firebase_app = firebase_admin.initialize_app(cred)
        except ValueError:
            # App already initialized
            _firebase_app = firebase_admin.get_app()
    return _firebase_app


class FirebaseAuthentication(authentication.BaseAuthentication):
    """
    Firebase token authentication.
    Clients should authenticate by passing the Firebase ID token in the
    "Authorization" header using the "Bearer" scheme.
    """

    def authenticate(self, request):
        """Authenticate the request and return a user."""
        auth_header = request.META.get('HTTP_AUTHORIZATION')
        if not auth_header:
            return None

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return None

        token = parts[1]

        try:
            # Verify the Firebase token
            get_firebase_app()
            decoded_token = firebase_auth.verify_id_token(token)
            uid = decoded_token.get('uid')

            if not uid:
                raise exceptions.AuthenticationFailed('Invalid token: no UID')

            # Get or create user
            from api.models import User
            user, created = User.objects.get_or_create(
                firebase_uid=uid,
                defaults={
                    'username': uid,
                    'email': decoded_token.get('email', ''),
                    'display_name': decoded_token.get('name', ''),
                }
            )

            # Update user info if changed
            if not created:
                email = decoded_token.get('email')
                name = decoded_token.get('name')
                if email and user.email != email:
                    user.email = email
                if name and user.display_name != name:
                    user.display_name = name
                user.save()

            return (user, decoded_token)

        except firebase_admin.exceptions.FirebaseError as e:
            raise exceptions.AuthenticationFailed(f'Firebase error: {str(e)}')
        except Exception as e:
            raise exceptions.AuthenticationFailed(f'Authentication failed: {str(e)}')

    def authenticate_header(self, request):
        """Return a string to be used as the value of the WWW-Authenticate header."""
        return 'Bearer realm="api"'


class OptionalFirebaseAuthentication(FirebaseAuthentication):
    """
    Optional Firebase authentication that allows anonymous access.
    """

    def authenticate(self, request):
        """Authenticate if token provided, otherwise return None."""
        auth_header = request.META.get('HTTP_AUTHORIZATION')
        if not auth_header:
            return None
        return super().authenticate(request)
