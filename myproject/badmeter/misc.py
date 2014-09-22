
from __future__ import print_function
from datetime import datetime, date
from django.utils.timezone import make_aware
import os
import sys
import hashlib

def print_info(*objs):
    print("INFO: ", *objs, file=sys.stderr)

def strip_extra_spaces(str):
    try:
        return ' '.join(str.split())
    except:
        return ''

def ageinyears(born):
    today = date.today()
    return today.year - born.year - ((today.month, today.day) < (born.month, born.day))

def ageindays_string(born_datetime):
    return ''.join(str(datetime.now()-born_datetime).split('.')[:1])

def hash_md5_random_hexdigest():
    return hashlib.md5(os.urandom(5)).hexdigest()
