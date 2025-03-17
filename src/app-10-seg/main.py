import os
from flask import Flask #, render_template, request, redirect, url_for
from datetime import datetime
from flask_caching import Cache
    
app = Flask(__name__)

app.config['CACHE_TYPE'] = 'simple'
app.config['CACHE_DEFAULT_TIMEOUT'] = 180
cache = Cache(app)

from routes import *

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True)