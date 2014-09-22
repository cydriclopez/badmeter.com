"""
Django settings for myproject project.

For more information on this file, see
https://docs.djangoproject.com/en/1.6/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/1.6/ref/settings/
"""

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
import local_settings
import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(__file__))

# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/1.6/howto/deployment/checklist/


# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = local_settings.SECRET_KEY

# Recaptcha settings
PUBLIC_KEY = local_settings.PUBLIC_KEY
PRIVATE_KEY = local_settings.PRIVATE_KEY


TESTING = ("test" in sys.argv)

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True
TEMPLATE_DEBUG = True

ALLOWED_HOSTS = [
    '.badmeter.com',
    '.badmeter.com.',
]

# Application definition

INSTALLED_APPS = (
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'badmeter',
    # 'south',
)

MIDDLEWARE_CLASSES = (
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
)

TEMPLATE_CONTEXT_PROCESSORS = (
    'django.contrib.messages.context_processors.messages',
    'django.contrib.auth.context_processors.auth',
    'django.core.context_processors.static',
)

ROOT_URLCONF = 'myproject.urls'

WSGI_APPLICATION = 'myproject.wsgi.application'

# Database
# https://docs.djangoproject.com/en/1.6/ref/settings/#databases

#~ DATABASES = {
    #~ 'default': {
        #~ 'ENGINE': 'django.db.backends.sqlite3',
        #~ 'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
    #~ }
#~ }

DATABASES = {
    'default': {
        'ENGINE':'django.db.backends.postgresql_psycopg2',
        'NAME': 'badmeter',
        'USER': local_settings.DB_USER,
        'PASSWORD': local_settings.DB_PASSWORD,
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

# Internationalization
# https://docs.djangoproject.com/en/1.6/topics/i18n/

#~ LANGUAGE_CODE = 'en-us'
#~ TIME_ZONE = 'UTC'
#~ USE_I18N = True
#~ USE_L10N = True
#~ USE_TZ = True

SOUTH_TESTS_MIGRATE = False

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'America/Chicago'
USE_I18N = True
USE_L10N = True

# USE_TZ = False is needed to prevent conflict with "non-naive dates" in postgresql.
USE_TZ = False

SESSION_EXPIRE_AT_BROWSER_CLOSE = False
SESSION_COOKIE_AGE = 31536000   # 365 days
SESSION_COOKIE_HTTPONLY = True
#~ SESSION_COOKIE_DOMAIN = '.badmeter.com'
SESSION_COOKIE_DOMAIN = None

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/1.6/howto/static-files/

STATIC_URL = '/static/'
STATIC_ROOT = "/home/user1/Projects/badmeter.com/myproject/badmeter"
STATICFILES_DIRS = (
    "/home/user1/Projects/badmeter.com/myproject/badmeter/static",
)

TEMPLATE_DIRS = (
    "/home/user1/Projects/badmeter.com/myproject/badmeter/template",
)
