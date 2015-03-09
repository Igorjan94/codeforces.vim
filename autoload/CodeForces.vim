" Author: Igor Kolobov, Igorjan94, Igorjan94@{mail.ru, gmail.com, yandex.ru}, https://github.com/Igorjan94, http://codeforces.ru/profile/Igorjan94

let s:CodeForcesFrom = 1
let s:CodeForcesRoom = '0'
let s:CodeForcesPrefix = '/'.join(split(split(globpath(&rtp, 'CF/*.users'), '\n')[0], '/')[:-2], '/')
let s:CodeForcesContestListFrom = 0
let s:CodeForcesContestListPage = 100

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

SAMPLE_INPUT   = vim.eval('g:CodeForcesInput')
SAMPLE_OUTPUT  = vim.eval('g:CodeForcesOutput')
cf_domain      = vim.eval('g:CodeForcesDomain')
csrf_token     = vim.eval('g:CodeForcesToken')
x_user         = vim.eval('g:CodeForcesXUser')
prefix         = vim.eval('s:CodeForcesPrefix')
contestId      = vim.eval('g:CodeForcesContestId')
contestFormat  = vim.eval('g:CodeForcesContestFormat')
template       = vim.eval('g:CodeForcesTemplate')
username       = vim.eval('g:CodeForcesUsername')
countSt        = vim.eval('g:CodeForcesCount')
updateInterval = vim.eval('g:CodeForcesUpdateInterval')
countOfSubmits = vim.eval('g:CodeForcesCountOfSubmits')
http           = 'http://codeforces.' + cf_domain + '/'
api            = http + 'api/'

ext_id          =  {
    'cpp':   '16',
    'cs':    '9',
    'c':     '10',
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
    'js':    '34'
}

def entity2char(x):
    if x.startswith('&#x'):
        return chr(int(x[3:-1],16))
    elif x.startswith('&#'):
        return chr(int(x[2:-1]))   
    else:
        return chr(int(x))

# CFSP {{{
class CodeForcesSubmissionParser(HTMLParser):

    def __init__(self):
        HTMLParser.__init__(self)
        self.parsing = False
        self.submission = ''

    def handle_starttag(self, tag, attrs):
        if tag == 'pre':
            for (x, y) in attrs:
                if x == 'class' and y == 'prettyprint':
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
        self.ok = False

    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            if self.parsing > 0:
                self.parsing += 1
            try:
                (x, y) = attrs[0]
                if x == 'class' and y == 'datatable':
                    self.parsing = 1
            except:
                42
        if tag == 'td':
            if self.parsing > 0:
                self.ok = True 

    def handle_endtag(self, tag):
        if tag == 'div':
            if self.parsing > 0:
                self.parsing -= 1
        if tag == 'td':
            if self.parsing > 0:
                self.ok = False
    
    def handle_data(self, data):
        if self.ok:
            self.friends += data.decode('utf-8')

    def handle_entityref(self, name):
        if self.ok:
            self.friends += self.unescape(('&%s;' % name))

    def handle_charref(self, name):
        if self.ok:
            self.friends += entity2char(name)
#}}}

def parse_problem(folder, domain, contest, problem, needTests):
    url = http + 'contest/%s/problem/%s' % (contest, problem)
    parser = CodeForcesProblemParser(folder, needTests, problem)
    parser.feed(requests.get(url).text.encode('utf-8'))
    return parser.problem[:-1].encode('utf-8')

def color(rating):
    if rating == 0:
        return 'Unrated'
    if rating < 1200:
        return 'Gray'
    if rating < 1500:
        return 'Green'
    if rating < 1700:
        return 'Blue'
    if rating < 1900:
        return 'Purple'
    if rating < 2200:
        return 'Yellow'
    return 'Red'

def loadFriends():
    r = requests.post(http + 'ratings/friends/true', params = {'csrf_token': csrf_token}, cookies = {'X-User': x_user}).text.encode('utf-8')
    parser = CodeForcesFriendsParser()
    parser.feed(r)
    friends = parser.friends.encode('utf-8')
    friends = re.sub(r'(\s*\n\s*)+', '\n', friends)
    friends = re.sub(r'^(\s*\n\s*)+', '', friends)
    counter = 0
    fileFriends = open(prefix + '/codeforces.friends', 'w')
    for x in friends.split('\n'):
        if counter % 4 == 1:
            fileFriends.write(x + '\n')
        counter += 1

def getProblems(contestId):
    return [(x['index'], x['name']) for x in requests.get(api + 'contest.standings?contestId=%s' % (contestId)).json()['result']['problems']]
EOF
"}}}

function! CodeForces#CodeForcesParseContest() "{{{
let directory = expand('%:p:h')
echom 'Parsing contest'
python << EOF

def parse(folder, cf_domain, contestId, index, flag):
    print('here')
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
    showUnofficial = ''
    friends = ''
    room = ''
    contestId = vim.eval('g:CodeForcesContestId')
    if vim.eval('s:CodeForcesRoom') != '0':
        try:
            room = '&room=' + str(requests.get(api + 'contest.standings?contestId=' + contestId + '&handles=' + username + '&showUnofficial=true').json()['result']['rows'][0]['party']['room'])
        except:
            print('No rooms or smthng else')
    if vim.eval('g:CodeForcesFriends') != '0':
        friends = '&handles=' + ';'.join(x[:-1] for x in open(prefix + '/codeforces.friends', 'r').readlines())
    if vim.eval('g:CodeForcesShowUnofficial') != '0':
        showUnofficial = '&showUnofficial=true'
    url = api + 'contest.standings?contestId=' + contestId + '&from=' + vim.eval('s:CodeForcesFrom') + '&count=' + countSt + showUnofficial + friends + room
    try:
        if vim.eval("expand('%:e')").lower() != 'standings':
            vim.command(vim.eval('g:CodeForcesCommandStandings') + ' ' + prefix + '/codeforces.standings')
            vim.command('call CodeForces#CodeForcesColor()')
        del vim.current.buffer[:]
        x = requests.get(url).json()
        if x['status'] != 'OK':
            vim.current.buffer.append('FAIL')
        else:
            x = x['result']
            contestName = x['contest']['name']
            problems = 'N|Party|Hacks|Score'
            for problem in x['problems']:
                price = ''
                if 'points' in problem.keys():
                    price = ' (' + str(int(problem['points'])) + ')'
                problems += ' | ' + problem['index'] + price
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
                if y['party']['participantType'] != 'CONTESTANT':
                    unof = '*'
                s = ' ' + str(y['rank']) + ' | ' + ', '.join(x['handle'] for x in y['party']['members']) + unof + ' | ' + hacks + '|' + str(int(y['points']))
                for pr in y['problemResults']:
                    s += ' | '
                    unsuc = pr['rejectedAttemptCount']
                    if pr['points'] == 0.0:
                        if unsuc != 0:
                            s += '-' + str(unsuc)
                    else:
                        if x['contest']['type'] == 'ICPC':
                            s += '+'
                            if unsuc > 0:
                                s += str(unsuc)
                        else:
                            s += str(int(pr['points']))
                vim.current.buffer.append(s.encode('utf-8'))
            vim.command("3,$EasyAlign *| {'a':'c'}")
            del vim.current.buffer[0]
    except Exception, e:
        print e
EOF
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
    py contestId = vim.eval('g:CodeForcesContestId')
endfunction
"}}}

function! CodeForces#CodeForcesColor() "{{{
    highlight Red     ctermfg=red 
    highlight Yellow  ctermfg=yellow
    highlight Purple  ctermfg=magenta
    highlight Blue    ctermfg=blue
    highlight Green   ctermfg=green
    highlight Gray    ctermfg=gray
    highlight Unrated ctermfg=white

    let x = matchadd('Green', ' +')
    let x = matchadd('Green', '+[0-9]')
    let x = matchadd('Green', '+[0-9][0-9]')
    let x = matchadd('Green', ' [0-9][0-9][0-9]')
    let x = matchadd('Green', ' [0-9][0-9][0-9][0-9]')
    let x = matchadd('Green', ' [0-9][0-9][0-9][0-9][0-9]')
    let x = matchadd('Red', '-[0-9]')
    let x = matchadd('Red', '-[0-9][0-9]')
python << EOF
users = open(prefix + '/codeforces.users', 'r')
for user in users:
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
        handle = handle.replace(' ', '')
        index = vim.current.buffer[1].split('|', 4)[4].split('|')[i].split('(')[0].replace(' ', '')
        count = 20
        i = 1
        submissionId = -1
        submissionLang = ''
        while True:
            submissions = requests.get(api + 'contest.status?contestId=' + contestId + '&handle=' + handle +
                '&from=' + str(i) + '&count=' + str(count)).json()
            if submissions['status'] == 'OK':
                for submission in submissions['result']:
                    if submission['problem']['index'] == index:
                        submissionId = submission['id']
                        submissionLang = submission['programmingLanguage']
                        break
                if len(submissions) == 0 or submissionId != -1:
                    break
                i += count
        if submissionId != -1:
            submissionExt = '.'
            if 'C++' in submissionLang:
                submissionExt += 'cpp'
            elif 'Java' in submissionLang:
                submissionExt += 'java'
            elif 'ython' in submissionLang:
                submissionExt += 'py'
            elif 'Pas' in submissionLang:
                submissionExt += 'pas'
            elif 'uby' in submissionLang:
                submissionExt += 'rb'
            else:
                submissionExt += 'txt'
            vim.command(vim.eval('g:CodeForcesCommandSubmission') + ' ' + handle + index + submissionExt)
            del vim.current.buffer[:]

            parser = CodeForcesSubmissionParser()
            parser.feed(requests.get(http + 'contest/' + contestId + '/submission/' + str(submissionId)).text.encode('utf-8'))
            vim.current.buffer.append(parser.submission.encode('utf-8').split('\n'))

            del vim.current.buffer[0]
            vim.command('%s/\r//g')
            vim.command('w')
EOF
endfunction
"}}}

function! CodeForces#CodeForcesUserSubmissions() "{{{
python << EOF


def formatString(s):
    return str(s['problem']['contestId']) + s['problem']['index'] + ' ' + \
        '{:>25}'.format(s['verdict'] + '(' + str(s['passedTestCount'] + 1) + ') ') + str(s['timeConsumedMillis']) + ' ms'

while True:
    try:
        data = requests.get(api + 'user.status?handle=' + username + '&from=1&count=' + str(countOfSubmits)).json()['result']
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
    if data[0]['verdict'] != 'TESTING':
        break
    vim.command('sleep ' + str(updateInterval))
EOF
endfunction
"}}}

function! CodeForces#CodeForcesSubmitIndexed(contestId, problemIndex) "{{{
python << EOF

contestId = vim.eval('a:contestId')
filename   = vim.eval('a:problemIndex')
extension  = vim.eval("expand('%:e')").lower()
fullPath   = vim.eval("expand('%:p')")
if not extension in ext_id.keys():
    print("I don't know extension ." + extension + ' :(')
else:
    parts = {
            'csrf_token':            csrf_token,
            'action':                'submitSolutionFormSubmitted',
            'submittedProblemIndex': filename,
            'source':                open(fullPath, 'rb'),
            'programTypeId':         ext_id[extension],
            'sourceFile':            '',
            '_tta':                  '222'
    }
    print('you are submitting ' + str(contestId) + filename + '.' + extension)
    typeOfContest = 'contest/'
    if int(contestId) > 100000:
        typeOfContest = 'gym/'
    r = requests.post(http + typeOfContest + contestId + '/problem/' + filename,
        params  = {'csrf_token': csrf_token},
        files   = parts,
        cookies = {'X-User': x_user})
    print(r)
    if r.status_code == requests.codes.ok:
        print('Solution is successfully sent. Current time is ' + time.strftime('%H:%M:%S'))
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
call CodeForces#CodeForcesLoadTaskContestId(g:CodeForcesContestId, a:index)
endfunction
"}}}

function! CodeForces#CodeForcesLoadTaskContestId(contestId, index) "{{{
let directory = expand('%:p:h')
python << EOF

index = vim.eval('a:index').upper()
contestId = vim.eval('a:contestId')
directory = vim.eval('directory')
vim.command(vim.eval('g:CodeForcesCommandLoadTask') + ' ' + index + '.problem')
del vim.current.buffer[:]
vim.current.buffer.append(parse_problem(directory, cf_domain, contestId, index, False).split('\n'))
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

response = requests.post(http + 'data/contests',
                        params = {'csrf_token': csrf_token, 'action': 'getSolvedProblemCountsByContest'},
                        cookies = {'X-User': x_user})
if response.status_code == requests.codes.ok:
    solved_count = response.json()['solvedProblemCountsByContestId']
    total_count = response.json()['problemCountsByContestId']

url = api + 'contest.list?gym=false'
response = requests.get(url).json()
if vim.eval("expand('%:e')").lower() != 'contestlist':
    vim.command('tabnew ' + prefix + '/codeforces.contestList')
del vim.current.buffer[:]

if response['status'] != 'OK':
    vim.current.buffer.append('FAIL')
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
                time = -contest['relativeTimeSeconds']
                phase = '{}h {}m'.format(time / 3600, (time % 3600) / 60)
            contest['name'] = (contest['name'].encode('utf-8'))
            if contestId in solved_count:
                solved_cnt = solved_count[contestId]
                total_cnt = total_count[contestId]
                text = '{}|{}|{}|{} / {}'.format(contest['name'], contestId, phase, solved_cnt, total_cnt)
            else:
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
        vim.command('75')
    vim.command('CodeForcesStandings')
    vim.command('tabnext')
    vim.command('q')
    vim.command('cd %:p:h')
except Exception, e:
    print(e)
EOF
endfunction
"}}}
