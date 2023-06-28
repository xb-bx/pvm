module gameoflife

import builtins
import fn flush from builtins
import fn printchar from builtins
import fn printi64 from builtins
import fn println from builtins
import fn clear from builtins
import fn sleep from builtins
import fn rand from builtins

type Board 
    arr $i8
    width i64
    height i64
end

fn mult(n1 i64 n2 i64) i64
    locals 
        i i64
        res i64
    end

    jmp cond
    :body
        pushlocal res
        pushlocal n1
        add
        setlocal res

        pushlocal i
        pushi64 1
        add
        setlocal i
    :cond
        pushlocal n2
        pushlocal i
        lt
        jtrue body
    pushlocal res
    ret
end

fn newBoard(width i64 height i64) *Board
    locals 
        b Board
        board *Board
        i i64
    end
    pushlocal b
    box
    setlocal board
    
    
    pushlocal width
    pushlocal height
    call mult
    newobj $i8


    pushlocal board
    setfield Board:arr

    pushlocal width
    pushlocal board
    setfield Board:width
    
    pushlocal height
    pushlocal board
    setfield Board:height

    jmp cond
    :body
        pushi64 2
        pushi64 0
        call rand
        conv i8

        pushlocal board
        getfield Board:arr
        pushlocal i
        setindex

        pushlocal i
        pushi64 1
        add
        setlocal i
    :cond
        pushlocal board
        getfield Board:arr
        getlength
        pushlocal i
        lt
        jtrue body

    pushlocal board
    ret
end
fn set (board *Board x i64 y i64 value i8) void
    pushi64 1
    pushlocal board
    getfield Board:height
    sub
    pushlocal y
    gt
    not jtrue noth
        pushlocal board
        getfield Board:height
        pushlocal y
        sub
        setlocal y
        jmp endify
    :noth
        pushi64 0
        pushlocal y
        lt
        not jtrue endify
            pushlocal y
            pushlocal board
            getfield Board:height
            add
            setlocal y
    :endify

    pushi64 1
    pushlocal board
    getfield Board:width
    sub
    pushlocal x
    gt
    not jtrue notw
        pushlocal board
        getfield Board:width
        pushlocal x
        sub
        setlocal x
        jmp endifx
    :notw
        pushi64 0
        pushlocal x
        lt
        not jtrue endifx
            pushlocal x
            pushlocal board
            getfield Board:width
            add
            setlocal x
    :endifx
    pushlocal value 
    pushlocal board
    getfield Board:arr

    pushlocal y
    
    pushlocal board
    getfield Board:width
    
    call mult
    
    pushlocal x
    add
    

    setindex
    ret
end
fn get (board *Board x i64 y i64) i8
    pushi64 1
    pushlocal board
    getfield Board:height
    sub
    pushlocal y
    gt
    not jtrue noth
        pushlocal board
        getfield Board:height
        pushlocal y
        sub
        setlocal y
        jmp endify
    :noth
        pushi64 0
        pushlocal y
        lt
        not jtrue endify
            pushlocal y
            pushlocal board
            getfield Board:height
            add
            setlocal y
    :endify

    pushi64 1
    pushlocal board
    getfield Board:width
    sub
    pushlocal x
    gt
    not jtrue notw
        pushlocal board
        getfield Board:width
        pushlocal x
        sub
        setlocal x
        jmp endifx
    :notw
        pushi64 0
        pushlocal x
        lt
        not jtrue endifx
            pushlocal x
            pushlocal board
            getfield Board:width
            add
            setlocal x
    :endifx

    pushlocal board
    getfield Board:arr

    pushlocal y
    
    pushlocal board
    getfield Board:width
    
    call mult
    
    pushlocal x
    add
    

    getindex
    ret
end
fn countNeighbours(board *Board x i64 y i64) i64
    locals
        res i64
    end
    
    pushlocal y
    pushi64 1
    pushlocal x
    sub
    pushlocal board
    call get
    conv i64
    pushlocal res
    add
    setlocal res

    pushlocal y
    pushlocal x
    pushi64 1
    add
    pushlocal board
    call get
    conv i64
    pushlocal res
    add
    setlocal res

    pushi64 1
    pushlocal y
    sub
    pushlocal x
    pushlocal board
    call get
    conv i64
    pushlocal res
    add
    setlocal res

    pushlocal y
    pushi64 1
    add
    pushlocal x
    pushlocal board
    call get
    conv i64
    pushlocal res
    add
    setlocal res
    pushi64 1
    pushlocal y
    sub
    pushi64 1
    pushlocal x
    sub
    pushlocal board
    call get
    conv i64
    pushlocal res
    add
    setlocal res

    pushlocal y
    pushi64 1
    add
    pushlocal x
    pushi64 1
    add
    pushlocal board
    call get
    conv i64
    pushlocal res
    add
    setlocal res

    pushi64 1
    pushlocal y
    sub
    pushlocal x
    pushi64 1
    add
    pushlocal board
    call get
    conv i64
    pushlocal res
    add
    setlocal res

    pushlocal y
    pushi64 1
    add
    pushi64 1
    pushlocal x
    sub
    pushlocal board
    call get
    conv i64
    pushlocal res
    add
    setlocal res
:opipopi
    pushlocal res
    ret
end
fn printBoard (board *Board) void
    locals
        x i64
        y i64
    end
    jmp rowscond
    :rowsbody
        
        pushi64 0
        setlocal x

        jmp colscond
        :colsbody
            pushlocal y
            pushlocal x
            pushlocal board
            call get
            pushi8 0
            eq
            jtrue zero
                pushchar '*'
                call printchar
                jmp nextit
            :zero
                pushchar ' '
                call printchar
            :nextit
                pushlocal x
                pushi64 1
                add
                setlocal x
        :colscond
            
            pushlocal board
            getfield Board:width

            pushlocal x
            lt
            jtrue colsbody
        pushlocal y
        pushi64 1
        add
        setlocal y
        pushchar '\n'
        call printchar
    :rowscond
        pushlocal board
        getfield Board:height
        pushlocal y
        lt
        jtrue rowsbody 
    call flush
    ret
end
type Game
    current *Board
    next *Board
end

fn newGame(width i64 height i64) *Game
    locals
        g Game
        game *Game
    end
    pushlocal g
    box
    setlocal game

    pushlocal height
    pushlocal width 
    call newBoard
    pushlocal game
    setfield Game:current

    pushlocal height
    pushlocal width 
    call newBoard
    pushlocal game
    setfield Game:next

    pushlocal game
    ret
end
fn step(game *Game) void
    locals 
        x i64
        y i64
        current *Board
        next *Board
        temp *Board
        neighbours i64
    end

    pushlocal game
    getfield Game:current
    setlocal current

    
    pushlocal current
    getfield Board:height
    pushlocal current
    getfield Board:width
    call newBoard
    setlocal next
    jmp rowscond
    :rowsbody
        pushi64 0
        setlocal x
        jmp colscond
        :colsbody
            pushlocal y
            pushlocal x
            pushlocal current
            call countNeighbours
            setlocal neighbours


            pushlocal y
            pushlocal x
            pushlocal current
            call get

            pushi8 0
            eq
            jtrue dead
                pushi64 2
                pushlocal neighbours
                lt
                jtrue shouldDie
                pushi64 3
                pushlocal neighbours
                gt
                jtrue shouldDie
            pushi8 1
            pushlocal y
            pushlocal x
            pushlocal next
            call set
            jmp nextit
            :shouldDie
                pushi8 0
                pushlocal y
                pushlocal x
                pushlocal next
                call set

                jmp nextit
            :dead
                pushi8 0
                pushlocal y
                pushlocal x
                pushlocal next
                call set
                pushlocal neighbours
                pushi64 3
                eq
                not 
                jtrue nextit
                    pushi8 1
                    pushlocal y
                    pushlocal x
                    pushlocal next
                    call set
            :nextit
                pushlocal x
                pushi64 1
                add
                setlocal x
        :colscond
            pushlocal current
            getfield Board:width

            pushlocal x
            lt
            jtrue colsbody
        pushlocal y
        pushi64 1
        add
        setlocal y
    :rowscond
        pushlocal current 
        getfield Board:height
        pushlocal y
        lt
        jtrue rowsbody 
    pushlocal next
    setlocal temp

    pushlocal current
    setlocal next
    
    pushlocal temp
    setlocal current
    
    pushlocal current
    pushlocal game
    setfield Game:current

    pushlocal next
    pushlocal game
    setfield Game:next
    ret
end
fn main() void
    locals
        game *Game
    end
    
    pushi64 28
    pushi64 100
    call newGame

    setlocal game


    :llop 
    call clear
    pushlocal game
    getfield Game:current
    call printBoard
    pushlocal game
    call step

    jmp llop
    ret
end
