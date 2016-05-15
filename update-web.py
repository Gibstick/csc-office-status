#!/usr/bin/env python3
import time
import os
import subprocess
import markup
import signal
from datetime import datetime


# check if it is already running
if os.path.isfile('.office-lock')
    print('update-web is already running! Check for lock file.')
    sys.exit(0)

# handle signals
def handle_die(signal, frame):
    print('Quitting.')
    sys.exit(0)

signal.signal(signal.SIGINT, handle_die)
signal.signal(signal.SIGTERM, handle_die)
signal.signal(signal.SIGQUIT, handle_die)

# html goodies
def generate_header(f):
    print(r'<head>', file=f)
    print(r'<meta content="29" http-equiv="refresh" />', file=f)
    print(r'<meta charset="UTF-8"', file=f)
    print(r'</head>', file=f)



# begin
title = "Is the CSC office open?"
header = "Is the CSC office open?"
style = ('style.css',)

output_file = 'office-status.html'
temp_file = 'office-status.html.tmp'
history_file = 'history.txt'

interval = 29 # seconds, prime number

old_code = None

while true:
    print("Checking...")

    page = markup.page()
    page.meta(http_equiv="refresh", content=interval)
    footer = time.strftime("Last checked: %a, %d %b %Y %H:%M:%S (local server time)\n")
      
    retcode = subprocess.call("./openoffice.sh")
    
    status_string = ""
    is_open = "Dunno"
    if retcode == 0:
        is_open = "Open"
        status_string = "Yes."
    elif retcode == 1:
        is_open = "Closed"
        status_string = "No."
    elif retcode == 5:
        is_open = "Error5"
        status_string = "Dunno. Could not fetch webcam stream."
    else: 
        is_open = "Error {}".format(retcode)
        status_string = "Dunno. The script returned nonzero status {}".format(retcode)
  
    page.init(title=is_open, css=style)
    page.h1(header)

    page.p(status_string)
    page.p(footer, class_='footer')
    page.a("History", href='./office-status-history', class_='footer')

    with open (temp_file, 'w') as f:
        print(page, file=f)

    os.rename(temp_file, output_file)
    
    if retcode != old_code:
        with open(history_file, 'a') as histfile:
            print("{} {}".format(is_open, str(datetime.now())), file=histfile)
    old_code = retcode

    time.sleep(interval)


