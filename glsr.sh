#!/bin/bash
# Go Left, Straight, or Right?
# Copyright (c) 2018 Yu-Jie Lin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERNHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


VERSION=0.1.0

R_INTN=1
# maximum routes, default is ~10% of terminal width
MAX_R="$(($(tput cols) * 10 / 100))"

# probability of actions
P_TURN=10
# P_SPLIT determines if it's going to split, if so, then P_SPLIT3 determines if
# it's going to splitting into 3 routes or just 2 routes.
P_SPLIT=5
P_SPLIT3=5
P_NEW=5
P_DEADEND=5
COLOR=1
DELAY=0.05
MAX_STEPS=0
HELP="Usage: $(basename $0) [OPTIONS]
Go Left, Straight, or Right?

Options:

    -n [int > 0]    initial number of routes (Default: $R_INTN)
    -m [int > 0]    maximum routes (Default: $MAX_R)
    -t [float]      walking interval in seconds (Default: $DELAY)
    -s [int]        max steps (Default: $MAX_STEPS)

    -T [0-100]      probability of turning (Default: $P_TURN)
    -S [0-100]      probability of splitting (Default: $P_SPLIT)
    -3 [0-100]      probability of splitting into 3 routes if splitting
                    (Default: $P_SPLIT3)
    -N [0-100]      probability of new route (Default: $P_NEW)
    -Z [0-100]      probability of hitting dead end (Default: $P_DEADEND)

    -C              no colors

    -h              this help message
    -v              print version number
"

parse()
{
    while getopts "n:m:t:s:T:S:3:N:Z:Chv" arg; do
        case $arg in
            n)
                if ((OPTARG <= 0)); then
                    echo "-$arg: argument must be > 0" >&2
                    exit 1
                fi
                R_INTN="$OPTARG"
                ;;
            m)
                if ((OPTARG <= 0)); then
                    echo "-$arg: argument must be > 0" >&2
                    exit 1
                fi
                MAX_R="$OPTARG"
                ;;
            t)
                DELAY="$OPTARG"
                ;;
            s)
                MAX_STEPS="$OPTARG"
                ;;
            T)
                if ((OPTARG < 0 || OPTARG > 100)); then
                    echo "-$arg: argument must be in between 0 and 100" >&2
                    exit 1
                fi
                P_TURN="$OPTARG"
                ;;
            S)
                if ((OPTARG < 0 || OPTARG > 100)); then
                    echo "-$arg: argument must be in between 0 and 100" >&2
                    exit 1
                fi
                P_SPLIT="$OPTARG"
                ;;
            3)
                if ((OPTARG < 0 || OPTARG > 100)); then
                    echo "-$arg: argument must be in between 0 and 100" >&2
                    exit 1
                fi
                P_SPLIT3="$OPTARG"
                ;;
            N)
                if ((OPTARG < 0 || OPTARG > 100)); then
                    echo "-$arg: argument must be in between 0 and 100" >&2
                    exit 1
                fi
                P_NEW="$OPTARG"
                ;;
            Z)
                if ((OPTARG < 0 || OPTARG > 100)); then
                    echo "-$arg: argument must be in between 0 and 100" >&2
                    exit 1
                fi
                P_DEADEND="$OPTARG"
                ;;
            C)
                COLOR=0
                ;;
            h)
                echo -e "$HELP"
                exit 0
                ;;
            v)
                echo "$(basename -- "$0") $VERSION"
                exit 0
        esac
    done

    if ((R_INTN > MAX_R)); then
        echo 'initial number of routes can not be larger than maximum:' \
             "$R_INTN > $MAX_R" >&2
        exit 1
    fi
}


check()
{
    local MIN_BASH_VER=4
    if ((BASH_VERSINFO[0] < MIN_BASH_VER)); then
        echo "$(basename ${BASH_SOURNE[0]}) only supports" \
             "Bash $MIN_BASH_VER+" >&2
        exit 1
    fi
}


new_r()
{
    ((COLOR)) && RC+=($((31 + RANDOM * 6 / 32768)))
    RD+=($((RANDOM * 3 / 32768)))
    RP+=($((RANDOM * COLS / 32768)))
    RN="${#RD[@]}"
}


init()
{
    local i

    # line length
    COLS="$(tput cols)"
    STEPS=0

    # routes
    #   RN: count
    #   RC: color 31-36
    #   RD: direction value
    #       -> offset for walk() / calculating new position
    #            : RDS: direction symbol for draw()
    #                Going/Meaning
    #     0 -> -1: / Left
    #     1 ->  0: | Straight
    #     2 ->  1: \ Right
    #   RDS: direction symbols
    #   RP: position, 0-based
    RN=0
    declare -ga RC=() RD=() RP=()
    declare -ga RDS=([0]='/' [1]='|' [2]='\')
    ((COLOR)) && RDS[2]='\\'

    for ((i = 0; i < $R_INTN; i++)); do
        new_r
    done
}


draw()
{
    local i c d s p line
    declare -a L=()

    for ((i = 0; i < RN; i++)); do
        ((COLOR)) && c="${RC[i]}"
        d="${RD[i]}"
        s="${RDS[d]}"
        p="${RP[i]}"
        ((COLOR)) && L[p]="\\e[1;${c}m$s\\e[0m" || L[p]="$s"
    done

    # fill up blanks
    for ((i = 0; i < COLS; i++)); do
        : ${L[i]:= }
    done

    # join the symbols
    printf -v line '%s' "${L[@]}"
    ((COLOR)) && echo -e "$line" || echo "$line"
}


walk()
{
    local i d p

    # walk one step
    for ((i = 0; i < RN; i++)); do
        d="${RD[i]}"
        p="${RP[i]}"
        # boundary check / bounce off edges
        ((p <= 0 && d == 0)) && d=2 && p=-1
        ((p >= COLS - 1 && d == 2)) && d=0 && p="$COLS"
        ((p += d - 1))
        RD[i]="$d"
        RP[i]="$p"
    done
    ((STEPS++))
}


update()
{
    local i d p

    # dead ends
    if ((RN > 0 && RANDOM * 100 / 32768 < P_DEADEND)); then
        ((i = RANDOM * RN / 32768))
        ((COLOR)) && unset RC[i]
        unset RD[i]
        unset RP[i]
        # resetting indexes
        ((COLOR)) && RC=("${RC[@]}")
        RD=("${RD[@]}")
        RP=("${RP[@]}")
        RN="${#RD[@]}"
    fi

    # turn
    for ((i = 0; i < RN; i++)); do
        ((RANDOM * 100 / 32768 >= P_TURN)) && continue
        # only two possible directions to turn
        ((d=(${RD[i]} + (RANDOM * 2 / 32768) + 1) % 3))
        # adjust position for new direction (!= 1: straight)
        ((d != 1)) && ((RP[i] -= d - 1))
        ((RD[i] = d))
    done

    # if splitting, only splitting one route
    if ((RN < MAX_R && RANDOM * 100 / 32768 < P_SPLIT)); then
        ((i = RANDOM * RN / 32768))
        d="${RD[i]}"
        p="${RP[i]}"
        # do 3 split if MAX_R allows and at odds
        if ((RN - 1 < MAX_R && RANDOM * 100 / 32768 < P_SPLIT3)); then
            # splitting into 3 routes
            ((COLOR)) && \
                RC+=($((31 + RANDOM * 6 / 32768)) $((31 + RANDOM * 6 / 32768)))
            RD+=($(((d + 1) % 3)) $(((d + 2) % 3)))
            RP+=($p $p)
        else
            ((split_d=(${RD[i]} + (RANDOM * 2 / 32768) + 1) % 3))
            ((COLOR)) && RC+=($((31 + RANDOM * 6 / 32768)))
            RD+=($split_d)
            RP+=($p)
        fi
        RN="${#RD[@]}"
    fi

    # new route
    ((RN < MAX_R && RANDOM * 100 / 32768 < P_NEW)) && new_r
}


roll()
{
    stty -echo
    while REPLY=; read -t $DELAY -n 1; [[ -z "$REPLY" ]] ; do
        walk
        draw
        if ((MAX_STEPS > 0 && STEPS >= MAX_STEPS)); then
            break
        fi
        update
    done
    stty echo

    # empty standard input
    read -t 0.001 && cat </dev/stdin>/dev/null; :
}


main()
{
    check

    parse "$@"
    init
    roll
}


main "$@"
