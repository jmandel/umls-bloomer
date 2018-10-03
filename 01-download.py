#!/usr/bin/python
import requests
import os
import sys

username = os.getenv('UMLS_USERNAME')
password = os.getenv('UMLS_PASSWORD')

assert username
assert password

default_target_file = 'https://download.nlm.nih.gov/umls/kss/2018AA/umls-2018AA-full.zip'
target_file = os.getenv('UMLS_TARGET_FILE', default_target_file)

s = requests.Session()

login_page = s.get(target_file)
action_base = login_page.url.split('/cas/')[0]
action_path = login_page.text.split('form id="fm1" action="')[1].split('"')[0]
execution = login_page.text.split('name="execution" value="')[1].split('"')[0]

login_response = s.post(action_base + action_path, {
    'username': username,
    'password': password,
    'execution': execution,
    '_eventId': 'submit'
}, allow_redirects=False)

login_response.raise_for_status()
print(login_response.headers)
umls_content_response = requests.get(login_response.headers['Location'], stream=True)
with open('scratch/umls.zip', 'wb') as handle:
    kb_read = 0
    for block in umls_content_response.iter_content(1024):
        handle.write(block)
        kb_read += 1
        if kb_read%1000 == 0:
            sys.stdout.write('.')
            sys.stdout.flush()
