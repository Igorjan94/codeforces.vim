# CountZero files (http://github.com/cnt0/cfsubmit)
from urllib.parse import urljoin

# local server urls
SERVER_HOST = 'localhost'
SERVER_PORT = 8200
SERVER_ADDR = 'http://{}:{}/'.format(SERVER_HOST, SERVER_PORT)

# local server routes
INIT_SERVER_PART = 'init_server'
INIT_CONTEST_PART = 'init_contest'
SUBMIT_PART = 'submit'
CHECK_VARS_PART = 'check_vars'

# codeforces urls
CF_MAIN_URL = 'http://codeforces.com/'
CF_LOGIN_URL = urljoin(CF_MAIN_URL, 'enter')
