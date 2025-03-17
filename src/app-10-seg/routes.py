from main import app, cache
from flask import Flask, render_template, url_for, jsonify   
from datetime import datetime

# Rotas
@app.route('/')
def home():
    return render_template ("index.html")

@app.route('/datetime')
@cache.cached(timeout=10, key_prefix='datetime_page')
def datetime_page():
    return render_template("datetime.html")

@app.route('/hour', methods=['GET'])
def hour():
    return jsonify({"url": url_for('datetime_page')})