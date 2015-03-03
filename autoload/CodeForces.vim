" Author: Igor Kolobov, Igorjan94, Igorjan94@{mail.ru, gmail.com, yandex.ru}, https://github.com/Igorjan94, http://codeforces.ru/profile/Igorjan94

let s:CodeForcesFrom = 1
let s:CodeForcesRoom = '0'
let s:CodeForcesPrefix = '/'.join(split(split(globpath(&rtp, 'CF/*.friends'), '\n')[0], '/')[:-2], '/')

"{{{
python << EOF
import requests
import vim
from HTMLParser import HTMLParser

SAMPLE_INPUT  = vim.eval('g:CodeForcesInput')
SAMPLE_OUTPUT = vim.eval('g:CodeForcesOutput')
cf_domain  = vim.eval("g:CodeForcesDomain")
http = 'http://codeforces.' + cf_domain + '/'
api = http + "api/"
csrf_token = vim.eval("g:CodeForcesToken")
x_user     = vim.eval("g:CodeForcesXUser")

ext_id          =  {
    "cpp":   "16",
    "cs":    "9",
    "c":     "10",
    "hs":    "12",
    "java":  "36",
    "py":    "41",
    "py2":   "40",
    "py3":   "41",
    "d":     "28",
    "go":    "32",
    "ml":    "19",
    "pas":   "4",
    "dpr":   "3",
    "pl":    "13",
    "php":   "6",
    "rb":    "8",
    "scala": "20",
    "js":    "34"
}

class CodeforcesProblemParser(HTMLParser):

    def __init__(self, folder, needTests, index):
        HTMLParser.__init__(self)
        self.folder        = folder
        self.num_tests     = 0
        self.testcaseParse = False
        self.testcase      = None
        self.start_copy    = False
        self.test          = ''
        self.Pparse        = -2
        self.TMLparse      = 0
        self.problem       = ''
        self.pName         = False
        self.su            = False
        self.needTests     = needTests
        self.index         = index

    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            if attrs == [('class', 'title')]:
                if self.Pparse == -2:
                    self.pName = True
            if attrs == [('class', 'input')]:
                self.Pparse = -10
                self.num_tests += 1
                self.problem += 'Input:\n'
                self.test = '\n'
                if self.needTests:
                    self.testcase = open('%s/%s%s%d' % (self.folder, SAMPLE_INPUT, self.index, self.num_tests), 'w')
            elif attrs == [('class', 'output')]:
                self.test = '\n'
                self.problem += 'Output:\n'
                if self.needTests:
                    self.testcase = open('%s/%s%s%d' % (self.folder, SAMPLE_OUTPUT, self.index, self.num_tests), 'w')
            elif attrs == [('class', 'time-limit')]:
                self.TMLparse = 2
                self.problem += 'TL = '
            elif attrs == [('class', 'memory-limit')]:
                self.TMLparse = 2
                self.problem += 'ML = '
            elif attrs == []:
                if self.Pparse == 0:
                    self.Pparse = 1

        elif tag == 'pre':
            if self.test != '':
                self.start_copy = True
        elif tag == 'sub':
            if attrs == [('class', 'lower-index')]:
                if self.Pparse > 0:
                    self.problem += '_'
                    self.su = True
        elif tag == 'sup':
            if attrs == [('class', 'upper-index')]:
                if self.Pparse > 0:
                    self.problem += '^'
                    self.su = True

    def handle_endtag(self, tag):
        if tag == 'br':
            if self.start_copy:
                self.test += '\n'
                self.end_line = True
        if tag == 'p' or tag == 'div':
            if self.Pparse > 0:
                self.problem += '\n'
        if tag == 'pre':
            if self.start_copy:
                if not self.end_line:
                    self.test += '\n'
                self.test = self.test[1:]
                self.problem += self.test + '\n'
                if self.needTests:
                    self.testcase.write(self.test)
                    self.testcase.close()
                    self.testcase = None
                self.test = ''
                self.start_copy = False

    def handle_entityref(self, name):
        if self.start_copy:
            self.test += str(self.unescape(('&%s;' % name)))
        elif self.Pparse > 0:
            self.problem += str(self.unescape(('&%s;' % name)))

    def handle_data(self, data):
        if self.start_copy:
            self.test += str(data)
            self.end_line = False
        elif self.TMLparse > 0:
            if self.TMLparse == 1:
                self.problem += data + '\n'
                self.Pparse += 1
            self.TMLparse -= 1
        elif self.Pparse > 0:
            if self.su and ('-' in data or '+' in data):
                data = '(' + data + ')'
            self.su = False
            self.problem += str(data)
        elif self.pName:
            self.problem += str(data + '\n')
            self.pName = False

def parse_problem(folder, domain, contest, problem, needTests):
    url = http + 'contest/%s/problem/%s' % (contest, problem)
    parser = CodeforcesProblemParser(folder, needTests, problem)
    parser.feed(requests.get(url).text.encode('utf-8'))
    return parser.problem[:-1]
EOF
"}}}

function! CodeForces#CodeForcesParseContest() "{{{
let directory = expand('%:p:h')
python << EOF
import vim
import requests
import shutil
import os

contestFormat = vim.eval('g:CodeForcesContestFormat')
contestId = vim.eval('g:CodeForcesContestId')
contest_id = vim.eval('g:CodeForcesContestId')
directory = vim.eval('directory')
template = vim.eval('g:CodeForcesTemplate')
extension = vim.eval("fnamemodify('" + template + "', ':e')")
try:
    problems = [(x['index'], x['name']) for x in requests.get(http + 'api/contest.standings?contestId=%s' % (contestId)).json()['result']['problems']]
    for (index, name) in problems:
        folder = directory
        if contestFormat == '/index':
            folder += '/' + index
        if not os.path.exists(folder):
            os.makedirs(folder)
        shutil.copyfile(template, folder + '/' + index + '.' + extension)
        open('/'.join((folder, index + '.problem')), 'w').write(parse_problem(folder, cf_domain, contestId, index, True))
except:
    print(':((')
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
import vim
import requests
import json
if vim.eval("a:0") == '1':
    vim.command("let g:CodeForcesContestId = a:1")
if vim.eval("g:CodeForcesContestId") == 0:
    print("\"CodeForcesContestId is not set. Add it in .vimrc or just call :CodeForcesStandings <CodeForcesContestId>\"")
else:
    showUnofficial = ''
    friends = ''
    room = ''
    contest_id = vim.eval('g:CodeForcesContestId')
    if vim.eval('s:CodeForcesRoom') != '0':
        try:
            room = '&room=' + str(requests.get(api + 'contest.standings?contestId=' + contest_id + '&handles=' + vim.eval('g:CodeForcesUsername') + '&showUnofficial=true').json()['result']['rows'][0]['party']['room'])
        except:
            print('No rooms or smthng else')
    if vim.eval('g:CodeForcesFriends') != '0':
        friends = '&handles=' + ';'.join(x.split()[2] for x in open(vim.eval('s:CodeForcesPrefix') + '/codeforces.friends', 'r').readlines())
    if vim.eval('g:CodeForcesShowUnofficial') != '0':
        showUnofficial = '&showUnofficial=true'
    url = api + 'contest.standings?contestId=' + contest_id + '&from=' + vim.eval("s:CodeForcesFrom") + '&count=' + vim.eval("g:CodeForcesCount") + showUnofficial + friends + room
    try:
        if vim.eval("expand(\'%:e\')").lower() != 'standings':
            vim.command(vim.eval('g:CodeForcesCommandStandings') + ' ' + vim.eval('s:CodeForcesPrefix') + '/codeforces.standings')
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
                price = ""
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

    let x = matchadd("Green", ' +')
    let x = matchadd("Green", '+[0-9]')
    let x = matchadd("Green", '+[0-9][0-9]')
    let x = matchadd("Green", ' [0-9][0-9][0-9]')
    let x = matchadd("Green", ' [0-9][0-9][0-9][0-9]')
    let x = matchadd("Green", ' [0-9][0-9][0-9][0-9][0-9]')
    let x = matchadd("Red", '-[0-9]')
    let x = matchadd("Red", '-[0-9][0-9]')
python << EOF
import vim
users = open(vim.eval('s:CodeForcesPrefix') + '/codeforces.users', 'r')
for user in users:
    [handle, color] = user[:-1].split(' ', 1)
    s = 'let x = matchadd(\"' + color + '\", \"' + handle + '\")'
    vim.command(s)
EOF
endfunction
"}}}

function! CodeForces#CodeForcesSubmission() "{{{
python << EOF
import requests
import vim
import html2text

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
            submissions = requests.get(api + 'contest.status?contestId=' + vim.eval('g:CodeForcesContestId') + '&handle=' + handle +
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

            #TODO: rewrite it
            vim.current.buffer.append((''.join(html2text.html2text(requests.get(http + 'contest/' + vim.eval('g:CodeForcesContestId') + '/submission/' + str(submissionId)).text).split('->')[1:]).split('**:')[0].encode('utf-8').split('\n')))

            del vim.current.buffer[0:3]
            del vim.current.buffer[-7:]
            vim.command('1,$<')
            vim.command('%s/\r//g')
            vim.command('w')
EOF
endfunction
"}}}

function! CodeForces#CodeForcesUserSubmissions() "{{{
python << EOF
import vim
import requests
import time
from time import sleep

username       = vim.eval("g:CodeForcesUsername")
updateInterval = vim.eval("g:CodeForcesUpdateInterval")
countOfSubmits = vim.eval("g:CodeForcesCountOfSubmits")

def formatString(s):
    return str(s['problem']['contestId']) + s['problem']['index'] + " " + \
        '{:>25}'.format(s['verdict'] + "(" + str(s['passedTestCount'] + 1) + ") ") + str(s['timeConsumedMillis']) + " ms"

while True:
    try:
        data = requests.get(api + "user.status?handle=" + username + "&from=1&count=" + str(countOfSubmits)).json()['result']
    except:
        vim.command('sleep ' + str(updateInterval))
        continue
    print("last submits")
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
import vim
import time  
import requests

contest_id = vim.eval("a:contestId")
filename   = vim.eval("a:problemIndex")
extension  = vim.eval("expand(\'%:e\')").lower()
fullPath   = vim.eval("expand(\'%:p\')")
if not extension in ext_id.keys():
    print("I don't know extension ." + extension + " :(")
else:
    parts = {
            "csrf_token":            csrf_token,
            "action":                "submitSolutionFormSubmitted",
            "submittedProblemIndex": filename,
            "source":                open(fullPath, "rb"),
            "programTypeId":         ext_id[extension],
            "sourceFile":            "",
            "_tta":                  "222"
    }
    print("you are submitting " + str(contest_id) + filename + '.' + extension)
    typeOfContest = 'contest/'
    if int(contest_id) > 100000:
        typeOfContest = 'gym/'
    r = requests.post(http + typeOfContest + contest_id + "/problem/" + filename,
        params  = {"csrf_token": csrf_token},
        files   = parts,
        cookies = {"X-User": x_user})
    print(r)
    if r.status_code == requests.codes.ok:
        print("Solution is successfully sent. Current time is " + time.strftime("%H:%M:%S"))
EOF
call CodeForces#CodeForcesUserSubmissions()
endfunction
"}}}

function! CodeForces#CodeForcesSubmit() "{{{
"contest_id = vim.eval("g:CodeForcesContestId")
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
import vim

index = vim.eval("a:index").upper()
contestId = vim.eval("a:contestId")
directory = vim.eval("directory")
vim.command(vim.eval('g:CodeForcesCommandLoadTask') + ' ' + index + '.problem')
del vim.current.buffer[:]
vim.current.buffer.append(parse_problem(directory, cf_domain, contestId, index, False).split('\n'))
del vim.current.buffer[0]
EOF
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

"get friends not working "{{{
python << EOF
import vim
import requests
import html2text
import re
x_user = vim.eval('g:CodeForcesXUser')
csrf_token = vim.eval('g:CodeForcesToken')

def color(rating):
    if rating == 0:
        return "Unrated"
    if rating < 1200:
        return "Gray"
    if rating < 1500:
        return "Green"
    if rating < 1700:
        return "Blue"
    if rating < 1900:
        return "Purple"
    if rating < 2200:
        return "Yellow"
    return "Red"

def loadFriends():
    r = html2text.html2text(requests.post(http + "ratings/friends/true", params = {"csrf_token": csrf_token}, cookies = {"X-User": x_user}).text).split('---|---|---|---')[1].split('[Codeforces]')[0].replace('\n', '')
    r = re.sub(r'\(.*?\)', '', r)
    r = re.sub(r'\[.*?\]\[', '\n', r)
    for x in r.split('\n')[1:]:
        y = x.split('|')
        if len(y) >= 2:
            print(y[0][:-2] + ' ' + color(int(y[2].replace(' ', ''))))
EOF
"}}}

function! CodeForces#CodeForcesSetColors() "{{{
python << EOF
import vim
loadFriends()
EOF
endfunction
"}}}

function! CodeForces#CodeForcesContestList() "{{{
python << EOF
import vim
import requests
import json

response = requests.post(http + 'data/contests',
                        params = {'csrf_token': csrf_token, 'action': 'getSolvedProblemCountsByContest'},
                        cookies = {'X-User': x_user})
if response.status_code == requests.codes.ok:
    solved_count = response.json()['solvedProblemCountsByContestId']
    total_count = response.json()['problemCountsByContestId']

url = api + 'contest.list?gym=false'
response = requests.get(url).json()
vim.command('tabnew ' + vim.eval('s:CodeForcesPrefix') + '/codeforces.contestList')
del vim.current.buffer[:]

if response['status'] != 'OK':
    vim.current.buffer.append('FAIL')
else:
    vim.current.buffer.append("CONTEST|ID|PHASE|SOLVED")
    cnt = 0
    for contest in response['result']:
        contest_id = str(contest['id'])
        if contest['phase'] == 'FINISHED':
            phase = 'Finished'
        else:
            phase = "{}h {}m".format(
                    contest['relativeTimeSeconds'] / 3600,
                    (contest['relativeTimeSeconds'] % 3600) / 60)

        if contest_id in solved_count:
            solved_cnt = solved_count[contest_id]
            total_cnt = total_count[contest_id]
            text = "{}|{}|{}|{} / {}".format(contest['name'], contest['id'], phase, solved_cnt, total_cnt)
        else:
            contest['name'] = str(contest['name'].encode('utf-8'))
            text = "{}|{}|{}|0".format(contest['name'], contest['id'], phase)
        vim.current.buffer.append(text.decode('utf-8'))

        cnt += 1
        if cnt == 20:
            break
    vim.command("1,$EasyAlign *| {'a':'l'}")
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

