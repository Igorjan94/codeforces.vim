" Author: Igor Kolobov, Igorjan94, Igorjan94@{mail.ru, gmail.com, yandex.ru}, https://github.com/Igorjan94, http://codeforces.ru/profile/Igorjan94

let s:CodeForcesFrom = 1
let s:CodeForcesRoom = '0'
let s:CodeForcesPrefix = '/'.join(split(split(globpath(&rtp, 'CF/*.users'), '\n')[0], '/')[:-2], '/')
let s:CodeForcesContestListFrom = 0
let s:CodeForcesContestListPage = 100
let s:CodeForcesStatus = 'FINISHED'
let s:CodeForcesStatusChanged = 1

"{{{
python << EOF
import requests
import vim
import shutil
import re
import os
import time
import threading
from time import sleep
from HTMLParser import HTMLParser
from urlparse import urljoin

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

SAMPLE_INPUT   = vim.eval('g:CodeForcesInput')
SAMPLE_OUTPUT  = vim.eval('g:CodeForcesOutput')
cf_domain      = 'com'

prefix         = vim.eval('s:CodeForcesPrefix')
contestId      = vim.eval('g:CodeForcesContestId')
contestFormat  = vim.eval('g:CodeForcesContestFormat')
template       = vim.eval('g:CodeForcesTemplate')
username       = vim.eval('g:CodeForcesUsername')
password       = vim.eval('g:CodeForcesPassword')
countSt        = vim.eval('g:CodeForcesCount')
updateInterval = vim.eval('g:CodeForcesUpdateInterval')
countOfSubmits = vim.eval('g:CodeForcesCountOfSubmits')
http           = 'http://codeforces.' + cf_domain + '/'
api            = http + 'api/'
phase          = 0
typeOfContest  = 'contest/'
if int(contestId) > 100000:
    typeOfContest = 'gym/'
lang           = '&lang='
locale         = '?locale='
try:
    lang      += vim.eval('g:CodeForcesLang')
    locale    += vim.eval('g:CodeForcesLang')
except:
    lang      += 'en'
    locale    += 'en'


ext_id          =  {
    'cpp':   '54',
    'cs':    '9',
    'c':     '43',
    'hs':    '12',
    'java':  '36',
    'py':    '41',
    'py2':   '40',
    'py3':   '41',
    'd':     '28',
    'go':    '32',
    'ml':    '19',
    'pas':   '4',
    'dpr':   '3',
    'pl':    '13',
    'php':   '6',
    'rb':    '8',
    'scala': '20',
    'js':    '34',
    'pi':    '44',
    'kt':    '48'
}

def entity2char(x):
    if x.startswith('&#x'):
        return chr(int(x[3:-1],16))
    elif x.startswith('&#'):
        return chr(int(x[2:-1]))   
    else:
        return chr(int(x))

# Submitter{{{
def init_server(handle, password):
    data = { 'handle': handle, 'password': password }
    requests.get(urljoin(SERVER_ADDR, INIT_SERVER_PART), data=data)


def init_contest(contest_id):
    data = { 'num': contest_id }
    requests.get(urljoin(SERVER_ADDR, INIT_CONTEST_PART), data=data)


def submit(problem_id, lang, filename):
    data = { 'id': problem_id, 'lang': ext_id[lang], 'text': ''.join(open(filename, 'r').readlines()) }
    requests.post(urljoin(SERVER_ADDR, SUBMIT_PART), data=data)

def get_friends():
	return requests.get(urljoin(SERVER_ADDR, GET_FRIENDS_PART))

#}}}

# CFSP {{{
class CodeForcesSubmissionParser(HTMLParser):

    def __init__(self):
        HTMLParser.__init__(self)
        self.parsing = False
        self.submission = ''

    def handle_starttag(self, tag, attrs):
        if tag == 'pre':
            for (x, y) in attrs:
                if x == 'class' and y.find('prettyprint') != -1 and y.find('program-source') != -1:
                    self.parsing = True

    def handle_endtag(self, tag):
        if tag == 'pre' and self.parsing:
            self.parsing = False
    
    def handle_charref(self, name):
        if self.parsing:
            self.submission += entity2char(name)

    def handle_data(self, data):
        if self.parsing:
            self.submission += data.decode('utf-8')

    def handle_entityref(self, name):
        if self.parsing:
            self.submission += self.unescape(('&%s;' % name))

#}}} 

# CFPP {{{
class CodeForcesProblemParser(HTMLParser):

    def __init__(self, folder, needTests, index):
        HTMLParser.__init__(self)
        self.folder        = folder
        self.num_tests     = 0
        self.testcase      = None
        self.ps            = -1
        self.test          = ''
        self.problem       = ''
        self.su            = False
        self.needTests     = needTests
        self.index         = index
        self.start_copy    = False

    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            if self.ps > 0:
                self.ps += 1
            if attrs == [('class', 'problem-statement')]:
                self.ps = 1
            elif attrs == [('class', 'input')]:
                self.num_tests += 1
                self.test = '\n'
                if self.needTests:
                    vim.command('echom "Get input: {} {}"'.format(self.index, self.num_tests))
                    self.testcase = open('%s/%s%s%d' % (self.folder, SAMPLE_INPUT, self.index, self.num_tests), 'w')
            elif attrs == [('class', 'output')]:
                self.test = '\n'
                if self.needTests:
                    vim.command('echom "Get output: {} {}"'.format(self.index, self.num_tests))
                    self.testcase = open('%s/%s%s%d' % (self.folder, SAMPLE_OUTPUT, self.index, self.num_tests), 'w')
            elif attrs == [('class', 'sample-tests')]:
                if self.ps > 0:
                    self.problem += '\n'
        elif tag == 'p':
            if self.ps > 0:
                self.problem += '\n'
        elif tag == 'pre':
            if self.test != '':
                self.start_copy = True
        elif tag == 'sub':
            if attrs == [('class', 'lower-index')]:
                if self.ps > 0:
                    self.problem += '_'
                    self.su = True
        elif tag == 'sup':
            if attrs == [('class', 'upper-index')]:
                if self.ps > 0:
                    self.problem += '^'
                    self.su = True

    def handle_startendtag(self, tag, attrs):
        if tag == 'img':
            if self.ps > 0:
                for (x, y) in attrs:
                    if x == 'src':
                        self.problem += y.decode('utf-8')
        else:
            self.handle_starttag(tag, attrs)
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if (tag == 'br' or tag == 'div' or tag == 'pre') and self.ps > 0:
            self.problem += '\n'
        if tag == 'br':
            if self.start_copy:
                self.test += '\n'
                self.end_line = True
        if tag == 'div':
            if self.ps > 0:
                self.ps -= 1
        if tag == 'pre':
            if self.start_copy:
                if not self.end_line:
                    self.test += '\n'
                self.test = self.test[1:]
                if self.needTests:
                    self.testcase.write(self.test)
                    self.testcase.close()
                    self.testcase = None
                self.test = ''
                self.start_copy = False

    def handle_entityref(self, name):
        if self.start_copy:
            self.test += self.unescape(('&%s;' % name))
        elif self.ps > 0:
            self.problem += self.unescape(('&%s;' % name))

    def handle_charref(self, name):
        if self.start_copy:
            self.test += entity2char(name)
        elif self.ps > 0:
            self.problem += entity2char(name)

    def handle_data(self, data):
        if self.start_copy:
            self.test += data.decode('utf-8')
            self.end_line = False
        if self.ps > 0:
            if self.su and ('-' in data or '+' in data or '*' in data or '/' in data):
                data = '(' + data + ')'
            self.su = False
            self.problem += data.decode('utf-8')
#}}}

# CFFP {{{
class CodeForcesFriendsParser(HTMLParser):

    def __init__(self):
        HTMLParser.__init__(self)
        self.parsing = -1
        self.friends = ''
	
    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            if self.parsing > 0:
                self.parsing += 1
            try:
				(x, y) = attrs[0]
				if x == 'class' and y.find('datatable') != -1:
					self.parsing = 1
            except:
                42
        if tag == 'a':
			if self.parsing > 0:
				self.friends+=attrs[0][1].split('/')[2]+"\n"

    def handle_endtag(self, tag):
        if tag == 'div':
            if self.parsing > 0:
                self.parsing -= 1

#}}}

def parse_problem(folder, domain, contest, problem, needTests):
    url = http + 'contest/%s/problem/%s' % (contest, problem)
    parser = CodeForcesProblemParser(folder, needTests, problem)
    parser.feed(requests.get(url + locale).text.encode('utf-8'))
    return parser.problem[:-1].encode('utf-8')

def color(rating):
    if rating == 0:
        return 'Unrated'
    if rating < 1200:
        return 'Gray'
    if rating < 1400:
        return 'Green'
    if rating < 1600:
        return 'Cyan'
    if rating < 1900:
        return 'Blue'
    if rating < 2200:
        return 'Purple'
    if rating < 2400:
        return 'Yellow'
    return 'Red'

# Should be working
def loadFriends():
	r = get_friends().text.encode('utf-8')
	parser = CodeForcesFriendsParser()
	parser.feed(r + locale)
	friends = parser.friends
	counter = 0
	fileFriends = open(prefix + '/codeforces.friends', 'w')
	fileFriends.write(friends)
	print("Friend list loaded succesfully")

def getProblems(contestId):
    return [(x['index'], x['name']) for x in requests.get(api + 'contest.standings?contestId=%s%s' % (contestId, lang)  ).json()['result']['problems']]
EOF
"}}}

function! CodeForces#CodeForcesParseContest() "{{{
let directory = expand('%:p:h')
echom 'Parsing contest'
python << EOF

def parse(folder, cf_domain, contestId, index, flag):
    parsed = parse_problem(folder, cf_domain, contestId, index, True)
    open('/'.join((folder, index + '.problem')), 'w').write(parsed)

directory = vim.eval('directory')
extension = vim.eval("fnamemodify('" + template + "', ':e')")
problems = getProblems(contestId)
for (index, name) in problems:
    vim.command('echom "Parsing problem: {}"'.format(index))
    folder = directory
    if contestFormat == '/index':
        folder += '/' + index
    if not os.path.exists(folder):
        os.makedirs(folder)
    shutil.copyfile(template, folder + '/' + index + '.' + extension)
    download = threading.Thread(target=parse, args=(folder, cf_domain, contestId, index, True))
    download.start()
EOF
endfunction
"}}}

function! CodeForces#CodeForcesNextStandings() "{{{
    let s:CodeForcesFrom = s:CodeForcesFrom + g:CodeForcesCount
    call CodeForces#CodeForcesStandings(g:CodeForcesContestId)
endfunction
"}}}

function! CodeForces#CodeForcesPrevStandings() "{{{
    let s:CodeForcesFrom = s:CodeForcesFrom - g:CodeForcesCount
    if s:CodeForcesFrom < 0
        let s:CodeForcesFrom = 1
    endif
    call CodeForces#CodeForcesStandings(g:CodeForcesContestId)
endfunction
"}}}

function! CodeForces#CodeForcesContestListNext() "{{{
    let s:CodeForcesContestListFrom = s:CodeForcesContestListFrom + s:CodeForcesContestListPage
    call CodeForces#CodeForcesContestList()
endfunction
"}}}

function! CodeForces#CodeForcesContestListPrev() "{{{
    let s:CodeForcesContestListFrom = s:CodeForcesContestListFrom - s:CodeForcesContestListPage
    if s:CodeForcesContestListFrom < 0
        let s:CodeForcesContestListFrom = 0
    endif
    call CodeForces#CodeForcesContestList()
endfunction
"}}}

function! CodeForces#CodeForcesPageStandings(page) "{{{
    if a:page >= 1
        let s:CodeForcesFrom = (a:page - 1) * g:CodeForcesCount + 1
        call CodeForces#CodeForcesStandings(g:CodeForcesContestId)
    endif
endfunction
"}}}

function! CodeForces#CodeForcesRoomStandings() "{{{
    if s:CodeForcesRoom == 1
        let s:CodeForcesRoom = 0
        let s:CodeForcesFrom = 1
    else
        let s:CodeForcesRoom = 1
    endif
    call CodeForces#CodeForcesStandings(g:CodeForcesContestId)
endfunction
"}}}

function! CodeForces#CodeForcesStandings(...) "{{{
"DO NOT TOUCH IT, IT WORKS
python << EOF
if vim.eval('a:0') == '1':
    vim.command('let g:CodeForcesContestId = a:1')
if vim.eval('g:CodeForcesContestId') == 0:
    print('CodeForcesContestId is not set. Add it in .vimrc or just call :CodeForcesStandings <CodeForcesContestId>')
else:
    contestId = vim.eval('g:CodeForcesContestId')
    changes = True
    try:
        ratingChanges = requests.get('https://cf-predictor-frontend.herokuapp.com/GetNextRatingServlet?contestId=' + contestId).json()['result']
    except:
        changes = False
    params = {'handles' : '', 'room' : '', 'showUnofficial' : '', 'from' : vim.eval('s:CodeForcesFrom'), 'count' : countSt, 'contestId' : contestId}
    if vim.eval('s:CodeForcesRoom') != '0':
        try:
            params['room'] = str(requests.get(api + 'contest.standings?contestId=' + contestId + '&handles=' + username + '&showUnofficial=true' + lang).json()['result']['rows'][0]['party']['room'])
        except:
            print('No rooms or smthng else')
    if vim.eval('g:CodeForcesFriends') != '0':
        try:
            f = open(prefix + '/codeforces.friends', 'r')
        except:
            loadFriends()
            f = open(prefix + '/codeforces.friends', 'r')
        params['handles'] = ';'.join(x[:-1] for x in f.readlines())
    if vim.eval('g:CodeForcesShowUnofficial') != '0':
        params['showUnofficial'] = 'true'
    url = api + 'contest.standings'
    try:
        if vim.eval("expand('%:e')").lower() != 'standings':
            vim.command(vim.eval('g:CodeForcesCommandStandings') + ' ' + prefix + '/codeforces.standings')
            vim.command('call CodeForces#CodeForcesColor()')
        del vim.current.buffer[:]
        x = requests.get(url + '?' + '&'.join(str(x) + '=' + str(params[x]) for x in params) + lang)
        x = x.json()
        if x['status'] != 'OK':
            vim.current.buffer.append('FAIL, ' + x['comment'])
        else:
            x = x['result']
            st = x['contest']['phase']
            if st == 'SYSTEM_TEST':
                phase = 1
            else:
                phase = 0
            if x['contest']['type'] == 'ICPC':
                st = 'FINISHED'
            if st != vim.eval('s:CodeForcesStatus'):
                vim.command('let s:CodeForcesStatusChanged = 1')
            else:
                vim.command('let s:CodeForcesStatusChanged = 0')
            vim.command("let s:CodeForcesStatus = '" + st + "'")
            contestName = x['contest']['name']
            problems = 'N|Party|'
            if x['contest']['type'] == 'ICPC':
                problems += 'Penalty|Solved'
            else:
                problems += 'Hacks|Score'
            for problem in x['problems']:
                price = ''
                if 'points' in problem.keys():
                    price = ' (' + str(int(problem['points'])) + ')'
                problems += ' | ' + problem['index'] + price
            if changes:
                problems += ' | Rating change'
            if phase == 1:
                textSTATUS = requests.get(http + typeOfContest + contestId + '/problem/0').text
                indexSTATUS = textSTATUS.find('<span class="contest-state-regular">')
                if indexSTATUS != -1:
                    textSTATUS = textSTATUS[indexSTATUS + 36 : indexSTATUS + 44]
                    textSTATUS = textSTATUS[:textSTATUS.find('%') + 1]
                    contestName += ' (System testing: ' + textSTATUS + ')'

            vim.current.buffer.append(contestName.encode('utf-8'))
            vim.current.buffer.append(problems.encode('utf-8'))
            for y in x['rows']:
                hacks = ' '
                if y['successfulHackCount'] > 0:
                    hacks += '+' + str(y['successfulHackCount'])
                if y['unsuccessfulHackCount'] > 0:
                    if len(hacks) > 1:
                        hacks += '/'
                    hacks += '-' + str(y['unsuccessfulHackCount'])
                unof = ''
                if y['party']['participantType'] == 'OUT_OF_COMPETITION':
                    unof = '*'
                if y['party']['participantType'] == 'VIRTUAL':
                    unof = '#'
                if x['contest']['type'] == 'ICPC':
                    hacks = str(int(y['penalty']))
                members = ''
                handle = ''
                if 'teamName' in y['party']:
                    members = y['party']['teamName']
                    handle = members
                if 'members' in y['party'] and len(y['party']['members']) > 0:
                    temp = ', '.join(x['handle'] for x in y['party']['members'])
                    if members != '':
                        members += ': '
                    else:
                        handle = temp
                    members += temp
                s = ' ' + str(y['rank']) + ' | ' + members.replace('|', '/') + unof + ' | ' + hacks + '|' + str(int(y['points']))
                for pr in y['problemResults']:
                    s += ' | '
                    unsuc = pr['rejectedAttemptCount']
                    if pr['points'] == 0.0:
                        if pr['type'] == 'PRELIMINARY' and phase == 1:
                            s += '?'
                        else:
                            if unsuc != 0:
                                s += '-' + str(unsuc)
                    else:
                        if x['contest']['type'] == 'ICPC':
                            s += '+'
                            if unsuc > 0:
                                s += str(unsuc)
                        else:
                            s += str(int(pr['points']))
                if changes:
                    for cc in ratingChanges:
                        if cc['handle'] == handle or cc['rank'] == y['rank']:
                            diff = cc['newRating'] - cc['oldRating']
                            if diff > 0:
                                s += '|+' + str(diff)
                            else:
                                s += '|' + str(diff)
                            break
                vim.current.buffer.append(s.encode('utf-8'))
            vim.command("3,$EasyAlign *| {'a':'c'}")
            del vim.current.buffer[0]
    except Exception, e:
        print e
EOF
if s:CodeForcesStatusChanged == 1
    call CodeForces#CodeForcesColor()
endif
endfunction
"}}}

function! CodeForces#CodeForcesFriendsSet() "{{{
    if g:CodeForcesFriends == 0
        let g:CodeForcesFriends = 1
        let s:CodeForcesFrom = 1
    else
        let g:CodeForcesFriends = 0
    endif
    call CodeForces#CodeForcesStandings(g:CodeForcesContestId)
endfunction
"}}}

function! CodeForces#CodeForcesUnofficial() "{{{
    if g:CodeForcesShowUnofficial == 1
        let g:CodeForcesShowUnofficial = 0
    else
        let g:CodeForcesShowUnofficial = 1
    endif
    call CodeForces#CodeForcesStandings(g:CodeForcesContestId)
endfunction
"}}}

function! CodeForces#CodeForcesSetRound(id) "{{{
    let g:CodeForcesContestId = a:id
python << EOF
contestId = vim.eval('g:CodeForcesContestId')
init_contest(contestId)
typeOfContest  = 'contest/'
if int(contestId) > 100000:
    typeOfContest = 'gym/'
EOF
endfunction
"}}}

function! CodeForces#CodeForcesColor() "{{{
    highlight Red     ctermfg=red 
    highlight Yellow  ctermfg=yellow
    highlight Purple  ctermfg=magenta
    highlight Blue    ctermfg=blue
    highlight Cyan    ctermfg=cyan
    highlight Green   ctermfg=green
    highlight Gray    ctermfg=gray
    highlight Unrated ctermfg=white
    let color = 'Green'
    if s:CodeForcesStatus != 'FINISHED'
        let color = 'Blue'
    endif
    let x = matchadd(color, ' +')
    let x = matchadd(color, ' +[0-9]\+')
    let x = matchadd(color, ' [0-9][0-9][0-9]\+')
    let x = matchadd('Red', ' -[0-9]\+')
python << EOF
users = open(prefix + '/codeforces.users', 'r')
for user in users:
    if not ' ' in user:
        continue
    [handle, color] = user[:-1].split(' ', 1)
    s = "let x = matchadd('" + color + "', '" + handle + "')"
    vim.command(s)
EOF
endfunction
"}}}

function! CodeForces#CodeForcesSubmission() "{{{
python << EOF

(row, col) = vim.current.window.cursor
[n, handle, hacks, score, tasks] = vim.current.buffer[row - 1].split('|', 4)
col -= len(n + handle + hacks + score) + 4
if col >= 0 and tasks[col] != '|' and row > 2:
    submissions = tasks.split('|')
    i = 0
    while col > len(submissions[i]):
        col -= len(submissions[i]) + 1
        i += 1
    if i != -1:
        handle = handle.replace(' ', '').split(',')[0]
        index = vim.current.buffer[1].split('|', 4)[4].split('|')[i].split('(')[0].replace(' ', '')
        count = 200
        i = 1
        submissionId = -1
        submissionLang = ''
        while True:
            vim.command("echom 'searching submission'")
            submissions = requests.get(api + 'contest.status?contestId=' + contestId + '&handle=' + handle + '&from=' + str(i) + '&count=' + str(count) + lang).json()
            if submissions['status'] == 'OK':
                for submission in submissions['result']:
                    if submission['problem']['index'] == index:
                        submissionId = submission['id']
                        submissionLang = submission['programmingLanguage']
                        break
                if len(submissions) == 0 or submissionId != -1:
                    break
                i += count
            if i >= 200:
                break
        if submissionId != -1:
            submissionExt = '.'
            if 'C++' in submissionLang:
                submissionExt += 'cpp'
            elif 'Java' in submissionLang:
                submissionExt += 'java'
            elif 'py' in submissionLang.lower():
                submissionExt += 'py'
            elif 'Pas' in submissionLang:
                submissionExt += 'pas'
            elif 'uby' in submissionLang:
                submissionExt += 'rb'
            elif 'Perl' in submissionLang:
                submissionExt += 'pl'
            else:
                submissionExt += 'txt'
            vim.command(vim.eval('g:CodeForcesCommandSubmission') + ' ' + handle + index + submissionExt)
            del vim.current.buffer[:]

            parser = CodeForcesSubmissionParser()
            parser.feed(requests.get(http + typeOfContest + contestId + '/submission/' + str(submissionId) + locale).text.encode('utf-8').replace('\r', ''))
            vim.current.buffer.append(parser.submission.encode('utf-8').split('\n'))

            del vim.current.buffer[0]
            vim.command('w')
EOF
endfunction
"}}}

function! CodeForces#CodeForcesUserSubmissions() "{{{
python << EOF


def formatString(s):
    def getML(m):
        for suffix in ['B', 'KB', 'MB', 'GB']:
            if m <= 1024:
                return str(m), suffix
            m /= 1024

    ml, size = getML(s['memoryConsumedBytes'])
    return '{:6} {:>25} ({:<3} tests, {:<4} ms, {:<4} {:<2})'.format(
        str(s['problem']['contestId']) + s['problem']['index'],
        s['verdict'],
        str(s['passedTestCount'] + 1),
        str(s['timeConsumedMillis']),
        ml,
        size
    )

while True:
    try:
        data = requests.get(api + 'user.status?handle=' + username + '&from=1&count=' + str(countOfSubmits) + lang).json()['result']
    except:
        vim.command('sleep ' + str(updateInterval))
        continue
    print('last submits')
    for s in reversed(data):
        try:
            print(formatString(s))
        except:
            print('IN QUEUE')
    sys.stdout.flush()
    if 'verdict' in data[0].keys():
        if data[0]['verdict'] != 'TESTING':
            break
    vim.command('sleep ' + str(updateInterval))
EOF
endfunction
"}}}

function! CodeForces#CodeForcesSubmitIndexed(contestId, problemIndex) "{{{
python << EOF

filename   = vim.eval('a:problemIndex')
extension  = vim.eval("expand('%:e')").lower()
fullPath   = vim.eval("expand('%:p')")
if not extension in ext_id.keys():
    print("I don't know extension ." + extension + ' :(')
else:
    print('you are submitting ' + str(contestId) + filename + '.' + extension)
    submit(filename, extension, fullPath)
EOF
call CodeForces#CodeForcesUserSubmissions()
endfunction
"}}}

function! CodeForces#CodeForcesSubmit() "{{{
"contestId = vim.eval('g:CodeForcesContestId')
let filename = expand('%:r')
"let directory = expand('%:p:h:t')
let directory = g:CodeForcesContestId

"TODO: parsing of directory or filename if CodeForcesContestId is not set to find CodeForcesContestId and ProblemIndex
"supported format: some/long/path/513/B2.cpp (uncomment let directory = expand('%:p:h:t') to use this format)

call CodeForces#CodeForcesSubmitIndexed(directory, filename)
endfunction
"}}}

function! CodeForces#CodeForcesLoadTask(index) "{{{
call CodeForces#CodeForcesLoadTaskContestId(g:CodeForcesContestId, a:index, 'False')
endfunction
"}}}

function! CodeForces#CodeForcesLoadTaskWithTests(index) "{{{
call CodeForces#CodeForcesLoadTaskContestId(g:CodeForcesContestId, a:index, 'True')
endfunction
"}}}

function! CodeForces#CodeForcesLoadTaskContestId(contestId, index, tests) "{{{
let directory = expand('%:p:h')
python << EOF

index = vim.eval('a:index').upper()
contestId = vim.eval('a:contestId')
directory = vim.eval('directory')
needTests = vim.eval('a:tests')
vim.command(vim.eval('g:CodeForcesCommandLoadTask') + ' ' + index + '.problem')
del vim.current.buffer[:]
vim.current.buffer.append(parse_problem(directory, cf_domain, contestId, index, needTests == 'True').split('\n'))
del vim.current.buffer[0]
EOF
:%s/\n\n\n/\r\r/g
:%s/\n\n\n/\r\r/g
:w
:1
endfunction
"}}}

function! CodeForces#CodeForcesTest() "{{{
let s:i = 1
let s:correct = 0
let s:index = expand('%:r:t')
:silent make
while 1 > 0
    let s:inputfile = g:CodeForcesInput . s:index . s:i
    if !filereadable(s:inputfile)
        break
    endif
    let s:outputfile = g:CodeForcesOutput . s:index . s:i
    let s:useroutput = g:CodeForcesUserOutput . s:index . s:i
    :silent execute ('!./' . s:index . ' < ' . s:inputfile . ' > ' . s:useroutput)
    let s:diff = system('diff ' . s:outputfile . ' ' . s:useroutput)
    if s:diff == ''
        let s:correct += 1
    else
        echom 'Test ' . s:i
        echom s:diff
    endif
    let s:i += 1
endwhile
echom s:correct . ' / ' . (s:i - 1) . ' correct!'
endfunction
"}}}

function! CodeForces#CodeForcesLoadFriends() "{{{
py loadFriends()
endfunction
"}}}

function! CodeForces#CodeForcesContestList() "{{{
python << EOF

response = requests.get(http + 'data/contests')
if response.status_code == requests.codes.ok:
    solved_count = response.json()['solvedProblemCountsByContestId']
    total_count = response.json()['problemCountsByContestId']
else:
    print("fail loading contest list")

url = api + 'contest.list?gym=false'
response = requests.get(url + lang).json()
if vim.eval("expand('%:e')").lower() != 'contestlist':
    vim.command('tabnew ' + prefix + '/codeforces.contestList')
del vim.current.buffer[:]

if response['status'] != 'OK':
    vim.current.buffer.append('FAIL, ' + response['comment'])
else:
    vim.current.buffer.append('CONTEST|ID|PHASE|SOLVED')
    cnt = 0
    contest_from = int(vim.eval('s:CodeForcesContestListFrom'))
    contest_to = int(vim.eval('s:CodeForcesContestListFrom + s:CodeForcesContestListPage'))
    for contest in response['result']:
        if cnt >= contest_from:
            contestId = str(contest['id'])
            if contest['phase'] == 'FINISHED':
                phase = 'Finished'
            else:
                time = contest['relativeTimeSeconds']
                if contest['phase'] == 'BEFORE':
                    time = -time
                phase = '{}h {}m'.format(time / 3600, (time % 3600) / 60)
            contest['name'] = (contest['name'].encode('utf-8'))
            text = '{}|{}|{}|0'.format(contest['name'], contestId, phase)
            vim.current.buffer.append(text.decode('utf-8'))
        cnt += 1
        if cnt >= contest_to:
            break
    vim.command("1,$EasyAlign *| {'a':'l'}")
    if vim.current.buffer[0] == '':
        del vim.current.buffer[0]
    # s = 'let x = matchadd(\"' + color + '\", \"' + handle + '\")'
    # vim.command(s)
EOF
"if contestId in solved_count:
    "solved_cnt = solved_count[contestId]
    "total_cnt = total_count[contestId]
    "text = '{}|{}|{}|{} / {}'.format(contest['name'], contestId, phase, solved_cnt, total_cnt)
"else:
highlight Green ctermfg=green
match Green /\([0-9]\+\) \/ \1/

highlight keyword cterm=bold cterm=underline
let x=matchadd('keyword', 'CONTEST')
let x=matchadd('keyword', 'ID')
let x=matchadd('keyword', 'PHASE')
let x=matchadd('keyword', 'SOLVED')
endfunction
"}}}

function! CodeForces#CodeForcesOpenContest() "{{{
python << EOF
try:
    problems = getProblems(contestId)
    (x, y) = problems[0]
    vim.command('cd ' + x)
    for (x, y) in problems:
        vim.command('tabnew ../' + x + '/' + x + '.problem')
        vim.command('cd %:p:h')
        vim.command('vsplit ' + x + '.cpp')
        vim.command('67')
    vim.command('CodeForcesStandings')
    vim.command('tabnext')
    vim.command('q')
    vim.command('cd %:p:h')
except Exception, e:
    print(e)
EOF
endfunction
"}}}

function! CodeForces#CodeForcesInitServer() "{{{
python << EOF
init_server(username, password)
init_contest(contestId)
EOF
endfunction
"}}}
