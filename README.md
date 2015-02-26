# Vim plugin for CodeForces

## What allows to do

* Watch standings of contests ([Unofficial](http://i.imgur.com/yI5bhBs.png), [Friends](http://i.imgur.com/2o730zV.png), [Official](http://i.imgur.com/avSplri.png))
* Submit source code (thanks to [CountZero](http://codeforces.ru/blog/entry/14786]))
* Watch result of last user's submissions ([Results](http://i.imgur.com/hDWFJXo.png))
* Load text of problems ([Russian](http://i.imgur.com/Q5M9fsd.png) | [English](http://i.imgur.com/NAmMBEj.png))
* Download last submission of user to problem ([qwerty787788's solution to F](http://i.imgur.com/vqvZV7Y.png))

## What I'm planning to do

* Full coloring of standings (I tested it on 10k users, it runs veryveryvery slow. So, I leave it as it is or, please, say how to do it in other way)
* Room standings
* Parsing sapmles automatic testing like (C|J)Helper does
* Deleting unused code, local uncludes (C++)
* <s>Change `tabnew` to user-defined command</s> Done.
* ...

## Using and configuring

### Installation

* Use your favourite plugin manager, for example `Bundle 'Igorjan94/codeforces.vim'`, then `:PluginInstall`
* Just clone rep to your `.vim/` directory

all variables and functions have name with prefix 'CodeForces'

### Variables

set count of users on one page to 40(default 30):

- `let g:CodeForcesCount = 40`

set current round to 518(default doesn't exists):

- `let g:CodeForcesContestId = 518`

set interval results are updating after submit to 1 second(default 2):

- `let g:CodeForcesUpdateInterval = 1`

set count of displayed submissions to 10(default 5):

- `let g:CodeForcesCountOfSubmits = 10`

set domain to 'com'(default 'ru'):

- `let g:CodeForcesDomain = 'com'`

show unofficial(default false):

- `let g:CodeForcesShowUnofficial = 1`

show only friends(default false):

- `let g:CodeForcesFriends = 1`

set values to submit:  

[Cookies in opera](http://i.imgur.com/B3C2KtK.png)  
You should copy X-User value(92 hex digits) and JSession(32 hex digits without '-n1')

- `let g:CodeForcesXUser = [x] * 32 `
- `let g:CodeForcesToken = [x] * 92 `

set command to open standings/problem/submission (default 'tabnew'):

- `let g:CodeForcesCommandStandings = 'badd'`
- `let g:CodeForcesCommandLoadTask  = 'badd'`
- `let g:CodeForcesCommandSubmission= 'badd'`

set your handle:

- `let g:CodeForcesUsername = 'Igorjan94'`

### Functions

Next standings page:

- ` :CodeForcesNextStandings `

Prev standings page:

- ` :CodeForcesPrevStandings `

Get 10 standings page:

- ` :CodeForcesPageStandings 10`

Get standings 518 (if contestId is not set, then `g:CodeForcesContestId`):

- ` :CodeForcesStandings 518 `

Show friends if not shown and vice versa:

- ` :CodeForcesFriendsSet `

Show unofficial if not shown and vice versa:

- ` :CodeForcesUnofficial `

Set `g:CodeForcesContestId` to contestId:

- ` :CodeForcesSetRound 518`

Just beautiful standings:

- ` :CodeForcesColor `

Load last submission under cursor(like ctrl-click in browser):

- ` :CodeForcesSubmission `

Get last submissions:

- ` :CodeForcesUserSubmissions `

Submit opened file as problem B1 to 513 round

- ` :CodeForcesSubmitIndexed 513 B1 `

Submit opened file as B1.cpp to `g:CodeForcesContestId` round

- ` :CodeForcesSubmit `

Load problem B from `g:CodeForcesContestId`

- ` :CodeForcesLoadTask B `

Load problem B from contest 510

- ` :CodeForcesLoadTaskContestId 510 B `

### Bindings

Of course, bind it like you want, I just suggest this:

- ` noremap <leader>cfr <ESC>:CodeForcesSet_R_ound `
- ` noremap <leader>cfS <ESC>:CodeForces_S_ubmission<CR>`
- ` noremap <leader>cfp <ESC>:CodeForces_P_revStandings<CR>`
- ` noremap <leader>cfn <ESC>:CodeForces_N_extStandings<CR>`
- ` noremap <leader>cfs <ESC>:CodeForces_S_tandings<CR>`
- ` noremap <leader>cff <ESC>:CodeForces_F_riendsSet<CR>`
- ` noremap <leader>cfu <ESC>:CodeForces_U_nofficial<CR>`
- ` noremap <leader>cfl <ESC>:CodeForces_L_oadTask `
- ` noremap <leader>cfP <ESC>:CodeForces_P_ageStandings `

I think `<S-F5>` very difficult to press ocasionally, so:

- ` noremap <S-F5>  <ESC>:w<CR><ESC>:CodeForcesSubmit<CR>`
- ` noremap <S-F6>  <ESC>:w<CR><ESC>:CodeForcesUserSubmissions<CR>`

### Other

Folder CF:  
`codeforces.standings` -- file to store standings

`codeforces.users` -- file with colors. In next versions will be command-generated, now by hand. Let's color users how you want!
Format: `handle Color`  
`Color = { Red, Yellow, Purple, Blue, Green, Gray, Unrated }`

`codeforces.friends`
Just go to rating.friends page and copy friends in format `rank (rank) handle contestNumber rating`

## Dependencies

* Python
  * requests  (all network)
  * html2text (loadProblem, loadSubmission)
* [EasyAlign](https://github.com/junegunn/vim-easy-align) for beautiful standings 

## Known <s>bugs</s> features

* It doesn't check any information entered by user
* THEY MUST BE, I just haven't found'em

## Author

Igor Kolobov, aka Igorjan94

My cf:      Igorjan94  
My mail:    Igorjan94@{mail.ru, gmail.com}  
My github:  Igorjan94  
