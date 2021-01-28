import sys
import requests
import json
import copy
import datetime
import pyodbc
import xml.etree.ElementTree as ET
import traceback
import smtplib
from email.mime.text import MIMEText
import pscore


smtp_config = pscore.init_config(sys.argv[1])
pscore.main_sync()
pscore.de_init()
