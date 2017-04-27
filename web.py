"""
Simple web app for serving office status page.
"""
import sqlite3
import os
from datetime import datetime

import click # for command-line initdb
from flask import Flask, render_template, url_for, Blueprint

WARNING_THRESHOLD = 600

bp = Blueprint('homedir_prefix', __name__, template_folder='templates')
app = Flask(__name__)

@app.cli.command()
def initdb():
    """Initialize the database."""
    db_conn = sqlite3.connect("office_status.db")
    cursor = db_conn.cursor()
    cursor.execute('''
    create table if not exists office_statuses(status INTEGER, ts INTEGER)
    ''')
    db_conn.commit()
    db_conn.close()


def office_status_context(status, timestamp):
    """Return a dict of context for rendering
    the main template.

    Params:
        - status: a status code as an integer, or false
        - timestamp: a unix timestamp as an integer
    """
    title = {
        0 : 'Open.',
        1 : 'Closed.',
    }
    open_text = {
        0 : 'Yes.',
        1 : 'No.',
        5 : 'Unknown. Could not fetch webcam stream.',
        None : 'No data yet.'
    }

    if timestamp:
        last_checked = datetime \
            .utcfromtimestamp(timestamp) \
            .strftime('%Y-%m-%d %H:%M:%S')
    else:
        last_checked = 'No data.'


    current_time = datetime.now().timestamp()
    if timestamp and current_time - timestamp > WARNING_THRESHOLD:
        last_checked_seconds = round(datetime.now().timestamp() - timestamp)
    else:
        last_checked_seconds = None


    return {
        'title' : title.get(status) or "Unknown.",
        'open_text' : open_text.get(status) or "???",
        'last_checked' : last_checked,
        'css_url' : url_for('static', filename='style.css'),
        'last_checked_seconds' : last_checked_seconds,
    }

def fetch_status(db_conn):
    """Fetch latest status from the database.

    Always returns a tuple, but the tuple might contain None values.
    """
    cursor = db_conn.cursor()
    cursor.execute("select status, ts from office_statuses")
    # if we have no results, return a tuple of None, None
    return cursor.fetchone() or (None, None)

DB_CONN = sqlite3.connect("office_status.db")

@bp.route('/')
def main_route():
    "main app route"
    status = fetch_status(DB_CONN)
    context = office_status_context(*status)
    return render_template("main.html", **context)

app.register_blueprint(bp, url_prefix=os.getenv('OFFICE_STATUS_PREFIX', '/'))
