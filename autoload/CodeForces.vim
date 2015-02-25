" Author: Igor Kolobov, Igorjan94, Igorjan94@{mail.ru, gmail.com, yandex.ru}, https://github.com/Igorjan94, http://codeforces.ru/profile/Igorjan94

let s:CodeForcesFrom = 1
let s:CodeForcesPrefix = '/'.join(split(split(globpath(&rtp, 'CF/*.friends'), '\n')[0], '/')[:-2], '/')

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

function! CodeForces#CodeForcesStandings(...) "{{{
python << EOF
import vim
import requests
import json

if vim.eval("a:0") == 1:
    vim.command("let g:CodeForcesContestId = a:1")
if vim.eval("g:CodeForcesContestId") == 0:
    vim.command("echom \"CodeForcesContestId is not set. Add it in .vimrc or just call CodeForces#CodeForcesStandings <CodeForcesContestId>\"")
else:
    api = "http://codeforces." + vim.eval("g:CodeForcesDomain") + "/api/"
    showUnofficial = ''
    friends = ''
    if vim.eval('g:CodeForcesFriends') != '0':
        friends = '&handles=' + ';'.join(x.split()[2] for x in open(vim.eval('s:CodeForcesPrefix') + '/codeforces.friends', 'r').readlines())
    if vim.eval('g:CodeForcesShowUnofficial') != '0':
        showUnofficial = '&showUnofficial=true'
    url = api + 'contest.standings?contestId=' + vim.eval("g:CodeForcesContestId") + '&from=' + vim.eval("s:CodeForcesFrom") + '&count=' + vim.eval("g:CodeForcesCount") + showUnofficial + friends
    try:
        if vim.eval("expand(\'%:e\')").lower() != 'standings':
            vim.command('tabnew ' + vim.eval('s:CodeForcesPrefix') + '/codeforces.standings')
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
            vim.current.buffer.append(contestName)
            vim.current.buffer.append(problems)
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
                s = ' ' + str(y['rank']) + ' | ' + y['party']['members'][0]['handle'] + unof + ' | ' + hacks + '|' + str(int(y['points']))
                for pr in y['problemResults']:
                    s += ' | '
                    if pr['points'] == 0.0:
                        if pr['rejectedAttemptCount'] != 0:
                            s += '-' + str(pr['rejectedAttemptCount'])
                    else:
                        s += str(int(pr['points']))
                vim.current.buffer.append(s)
            vim.command("3,$EasyAlign *| {'a':'c'}")
            del vim.current.buffer[0]
    except Exception, e:
        print e
EOF
call CodeForces#CodeForcesColor()
endfunction
"}}}

function! CodeForces#CodeForcesFriendsSet() "{{{
    if g:CodeForcesFriends == 0
        let g:CodeForcesFriends = 1
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
            submissions = requests.get('http://codeforces.ru/api/contest.status?contestId=' + vim.eval('g:CodeForcesContestId') + '&handle=' + handle +
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
            vim.command('tabnew ' + handle + index + submissionExt)
            del vim.current.buffer[:]
            vim.current.buffer.append(''.join(html2text.html2text(requests.get('http://codeforces.' + vim.eval('g:CodeForcesDomain') + '/contest/' + vim.eval('g:CodeForcesContestId') + '/submission/' + str(submissionId)).text).split('->')[1:]).split('**:')[0].split('\n'))
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
        data = requests.get("http://codeforces.ru/api/user.status?handle=" + username + "&from=1&count=" + str(countOfSubmits)).json()['result']
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
cf_domain  = vim.eval("g:CodeForcesDomain")
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
    print("you are submitting  " + str(contest_id) + filename + '.' + extension)
    r = requests.post("http://codeforces." + cf_domain + "/contest/" + contest_id + "/problem/" + filename,
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
python << EOF
import vim
import requests
import html2text

index = vim.eval("a:index").upper()
contestId = vim.eval("a:contestId")
vim.command('tabnew ' + index + '.problem')
del vim.current.buffer[:]
#vim.current.buffer.append(index + '\r' + html2text.html2text(''.join(open("problem.txt", 'r').readlines())).split(index)[1].split('[Codeforces]')[0])
vim.current.buffer.append(html2text.html2text(requests.get('http://codeforces.' + vim.eval('g:CodeForcesDomain') + '/contest/' + contestId + '/problem/' + index).text).split(index + '.')[1].split('[Codeforces]')[0].split('\n'))
del vim.current.buffer[0]
del vim.current.buffer[1:4]
del vim.current.buffer[2:5]
del vim.current.buffer[3:12]
vim.current.buffer[0] = index + '.' + vim.current.buffer[0]
EOF
:%s/    \n/\r/g
:%s/\n\n\n/\r/g
endfunction
"}}}
