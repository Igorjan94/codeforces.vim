#!/usr/bin/env python3
#code of CountZero(http://github.com/cnt0/cfsubmit)

import time
try:
    from urlparse import urljoin
except:
    from urllib.parse import urljoin

from selenium.webdriver.support.ui import Select
from selenium import webdriver
from flask import request
from flask import Flask
from flask import g

# local server urls
SERVER_HOST = 'localhost'
SERVER_PORT = 8200
SERVER_ADDR = 'http://{}:{}/'.format(SERVER_HOST, SERVER_PORT)

# local server routes
INIT_SERVER_PART = 'init_server'
INIT_CONTEST_PART = 'init_contest'
SUBMIT_PART = 'submit'
GET_FRIENDS_PART = 'get_friends'

# codeforces urls
CF_MAIN_URL = 'http://codeforces.com/'
CF_LOGIN_URL = urljoin(CF_MAIN_URL, 'enter')
CF_FRIENDS_URL = urljoin(CF_MAIN_URL, 'friends')

if __name__ == '__main__':
    app = Flask(__name__)

    ctx = app.app_context()
    ctx.push()

    g.browser = webdriver.Chrome()
# g.browser = webdriver.PhantomJS()
    g.browser.set_window_size(1020, 2020)

    g.handle = ''
    g.password = ''

    g.default_url = CF_MAIN_URL
    g.login_url = CF_LOGIN_URL
    g.submit_url = ''

    g.browser.get(g.default_url)


    def sleep():
        time.sleep(1)


    def login():
        if g.browser.current_url == g.submit_url:
            return
        if g.browser.current_url != g.login_url:
            g.browser.get(g.login_url)
            sleep()
        g.browser.find_element_by_id("handleOrEmail").send_keys(g.handle)
        g.browser.find_element_by_id("password").send_keys(g.password)
        g.browser.find_element_by_id("remember").click()
        sleep()
        g.browser.find_element_by_class_name("submit").submit()
        sleep()


    @app.route(urljoin('/', INIT_CONTEST_PART))
    def init_contest():
        contestId = request.form['num']
        g.submit_url = urljoin(g.default_url, '{}/{}/submit'.format('contest' if int(contestId) < 100000 else 'gym', contestId))
        g.browser.get(g.submit_url)
        return "contest {} initialized".format(g.submit_url)


    @app.route(urljoin('/', INIT_SERVER_PART))
    def init_server():
        g.handle = request.form['handle']
        g.password = request.form['password']
        login()
        return "server initialized"


    def cf_submit(id, lang, text):
        try:
            Select(g.browser.find_element_by_name('submittedProblemIndex')).select_by_value(id)
            Select(g.browser.find_element_by_name('programTypeId')).select_by_value(lang)
            g.browser.execute_script("editAreaLoader.setValue('sourceCodeTextarea', String.raw`{}`)".format(request.form['text']))
            time.sleep(1)
            g.browser.find_element_by_class_name('submit').submit()
        except Exception as e:
            print(e)


    @app.route(urljoin('/', GET_FRIENDS_PART))
    def get_friends():
        if g.browser.current_url != CF_FRIENDS_URL:
            g.browser.get(CF_FRIENDS_URL)
            sleep()
        return g.browser.page_source

    @app.route(urljoin('/', SUBMIT_PART), methods=['POST'])
    def submit():
        cf_submit(request.form['id'], request.form['lang'], request.form['text'])
        sleep()
        g.browser.get(g.submit_url)
        return "solution sent"

    app.run(SERVER_HOST, SERVER_PORT)
