'''
Simple web app for serving office status page.
'''
import sqlite3
import os
from datetime import datetime

from flask import Flask, render_template, url_for
from werkzeug.serving import run_simple
from werkzeug.wsgi import DispatcherMiddleware


WARNING_THRESHOLD = 600
PREFIX = os.getenv('OFFICE_STATUS_PREFIX', '/')
DATE_FORMAT = '%B %d, %Y %H:%M:%S'

app = Flask(__name__)
app.config["APPLICATION_ROOT"] = PREFIX


def office_status_context(status, timestamp, since_timestamp):
    '''Return a dict of context for rendering
    the main template.

    Params:
        - status: a status code as an integer, or false
        - timestamp: a unix timestamp as an integer
        - last_open_timestamp: timestamp of when the office was last open
    '''
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
    since_text_prefix = {
        0 : 'Open since',
        1 : 'Closed since',
    }

    if timestamp:
        last_checked = datetime \
            .fromtimestamp(timestamp) \
            .strftime(DATE_FORMAT)
    else:
        last_checked = 'No data.'


    current_time = datetime.now().timestamp()
    if timestamp and current_time - timestamp > WARNING_THRESHOLD:
        last_checked_seconds = round(current_time - timestamp)
    else:
        last_checked_seconds = None

    if since_timestamp:
        since_date = datetime \
            .fromtimestamp(since_timestamp) \
            .strftime(DATE_FORMAT)
        since_text = (since_text_prefix.get(status) or "Broken since") \
            + " " + since_date
        print(since_date)
    else:
        since_text = None


    return {
        'title' : title.get(status) or "Unknown.",
        'open_text' : open_text.get(status) or "???",
        'last_checked' : last_checked,
        'css_url' : url_for('static', filename='style.css'),
        'last_checked_seconds' : last_checked_seconds,
        'since_text' : since_text
    }

def fetch_status(db_conn):
    '''Fetch latest status from the database.

    Always returns a tuple, but the tuple might contain None values.
    '''
    try:
        cursor = db_conn.cursor()
        cursor.execute("select status, max(ts) from office_statuses")
        # if we have no results, return a tuple of None, None
        return cursor.fetchone() or (None, None)
    except sqlite3.Error:
        return (None, None)

def fetch_last_status_change(db_conn, status):
    '''Query for the last time the status changed

    Returns None if nothing was found
    '''
    try:
        cursor = db_conn.cursor()
        cursor.execute("select max(ts) from office_status_deltas")
        result = cursor.fetchone()
        if result:
            return result[0]
        else:
            return None
    except sqlite3.Error:
        return None


@app.route('/')
def main_route():
    db_conn = sqlite3.connect("office_status.db")
    office_status, timestamp = fetch_status(db_conn)
    since_timestamp = fetch_last_status_change(db_conn, office_status)
    context = office_status_context(office_status, timestamp, since_timestamp)
    return render_template("main.html", **context)

def dummy(env, resp):
    # TODO: send a better response
    resp('200 OK', [('Content-Type', 'text/plain')])
    return [b"This is not the route you're looking for."]


# need to check for this or else we get infinite redirects
# and the app won't work on /
if PREFIX != '/':
    app.wsgi_app = DispatcherMiddleware(dummy, {PREFIX : app.wsgi_app})


if __name__ == '__main__':
    run_simple('localhost', 58888, app, use_reloader=True)
