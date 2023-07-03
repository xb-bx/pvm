module minesweeper

import builtins
import fn println from builtins
import fn printchar from builtins
import fn flush from builtins
import fn getch from builtins
import fn clear from builtins
import fn rand from builtins
import fn sleep from builtins
type Cell
    isBomb bool
    isTested bool
    bombsAround i32
end
type Game 
    board $$Cell
    w i32
    h i32
    selectedX i32
    selectedY i32
    numberOfBombs i32
    gameOver bool
end
fn fillBoard (game *Game) void
    locals 
        bombs i32
        x i64
        y i64
        ix i64
        iy i64
    end
    pushi32 0
    setlocal bombs
    :bloop
        pushlocal game ; x = rand(0, w)
        getfield Game:w
        conv i64
        pushi64 0
        call rand
        setlocal x

        pushlocal game ; y = rand(0, h)
        getfield Game:h
        conv i64
        pushi64 0
        call rand
        setlocal y

        pushlocal y ; if isBomb(game, x, y) continue
        pushlocal x
        pushlocal game
        call isBomb
        jtrue bloop



        pushtrue ; game.board[y][x].isBomb = true
        pushlocal game
        getfield Game:board
        pushlocal y
        getindex
        pushlocal x
        getindexref
        setfield Cell:isBomb



        pushi64 -1
        setlocal iy
        :yloop
            pushi64 -1
            setlocal ix
            :xloop
                pushlocal iy
                pushlocal y
                add

                pushlocal ix
                pushlocal x
                add

                pushlocal game
                call incrementBombs
                
                pushlocal ix
                pushi64 1
                add
                setlocal ix
            :xcond
                pushi64 2
                pushlocal ix
                lt
                jtrue xloop
            pushlocal iy
            pushi64 1
            add 
            setlocal iy

        :ycond
            pushi64 2
            pushlocal iy
            lt
            jtrue yloop



        pushlocal bombs
        pushi32 1
        add
        setlocal bombs
    :cond
        pushlocal game
        getfield Game:numberOfBombs
        pushlocal bombs
        lt
        jtrue bloop
    ret
end
fn isBomb (game *Game x i64 y i64) bool 
    
    pushi64 0
    pushlocal x
    lt
    jtrue notabomb

    pushi64 0
    pushlocal y
    lt
    jtrue notabomb

    pushlocal game
    getfield Game:w
    conv i64
    pushlocal x
    pushi64 1
    add
    gt
    jtrue notabomb

    pushlocal game
    getfield Game:h
    conv i64
    pushlocal y
    pushi64 1
    add
    gt
    jtrue notabomb

    pushlocal game
    getfield Game:board
    pushlocal y
    getindex
    pushlocal x
    getindexref
    getfield Cell:isBomb
    ret

    :notabomb

        pushfalse
        ret
end

fn incrementBombs (game *Game x i64 y i64) void 
    locals 
        bombs &i32
    end
    pushi64 0
    pushlocal x
    lt
    jtrue outofbounds

    pushi64 0
    pushlocal y
    lt
    jtrue outofbounds

    pushlocal game
    getfield Game:w
    conv i64
    pushlocal x
    pushi64 1
    add
    gt
    jtrue outofbounds

    pushlocal game
    getfield Game:h
    conv i64
    pushlocal y
    pushi64 1
    add
    gt
    jtrue outofbounds


    pushlocal game
    getfield Game:board
    pushlocal y
    getindex
    pushlocal x
    getindexref
    getfieldref Cell:bombsAround
    setlocal bombs
    pushlocal bombs
    deref
    pushi32 1
    add
    pushlocal bombs
    storeref
    ret
    
    :outofbounds
        ret
end
fn newGame (w i32 h i32 bombs i32) Game
    locals
        g Game
        i i32

    end
    pushlocal w
    reflocal g
    setfield Game:w
    pushlocal h
    reflocal g
    setfield Game:h
   
    pushlocal h
    conv i64
    newobj $$Cell
    reflocal g
    setfield Game:board
    pushlocal bombs
    reflocal g
    setfield Game:numberOfBombs
    
    pushi32 0
    setlocal i
    :loop
        pushlocal w
        conv i64
        newobj $Cell
        reflocal g
        getfield Game:board
        pushlocal i
        conv i64
        setindex 
        pushi32 1
        pushlocal i
        add
        setlocal i
    :cond
        pushlocal h
        pushlocal i
        lt
        jtrue loop
    pushlocal g
    ret    
end
fn printBoard (game *Game) void
    locals
        x i64
        y i64
        i i32
        selectedX i64
        selectedY i64
        cell Cell
        around i32
        out char
    end
    pushlocal game
    getfield Game:selectedX
    conv i64
    setlocal selectedX
    pushlocal game
    getfield Game:selectedY
    conv i64
    setlocal selectedY




    pushi32 0
    setlocal i
    pushchar '-'
    call printchar
    :rloop
        pushchar '-'
        call printchar
        pushchar '-'
        call printchar
        pushchar '-'
        call printchar
        pushchar '-'
        call printchar
        pushlocal i
        pushi32 1
        add
        setlocal i
    :rcond
        pushlocal game
        getfield Game:w
        pushlocal i
        lt
        jtrue rloop
    call flush
    :yloop
        pushi64 0
        setlocal x
        pushchar '|'
        call printchar
        :xloop
            pushlocal x
            pushlocal selectedX
            eq
            not
            jtrue notsel
            pushlocal y
            pushlocal selectedY
            eq
            not
            jtrue notsel

            pushchar '|'
            pushchar ' '
            pushchar '@'
            pushchar ' '
            call printchar
            call printchar
            call printchar
            call printchar
            jmp incr
            

            :notsel
                
                pushlocal game
                getfield Game:board
                pushlocal y
                getindex
                pushlocal x
                getindex
                setlocal cell
                reflocal cell
                getfield Cell:bombsAround
                setlocal around
                

                reflocal cell
                getfield Cell:isTested
                jtrue tested
                    pushchar '.'
                    setlocal out
                    jmp endswitch
                :tested
                    reflocal cell
                    getfield Cell:isBomb
                    not
                    jtrue notbomb
                    pushchar '*'
                    setlocal out
                    jmp endswitch
                :notbomb
                    pushlocal around
                    pushi32 0
                    eq
                    not
                    jtrue notzero
                    pushchar ' '
                    setlocal out
                    jmp endswitch
                :notzero
                    pushlocal around
                    pushchar '0'
                    conv i32
                    add
                    conv char
                    setlocal out
                :endswitch
                pushlocal out
                pushchar ' '
                call printchar
                call printchar
                pushchar '|'
                pushchar ' '
                call printchar
                call printchar
            :incr
                pushi64 1
                pushlocal x
                add
                setlocal x
        :xcond
            pushlocal game
            getfield Game:w
            pushlocal x
            conv i32
            lt
            jtrue xloop
        pushchar '\n'
        call printchar
        
        pushi32 0
        setlocal i
        pushchar '-'
        call printchar
        :lloop
            pushchar '-'
            call printchar
            pushchar '-'
            call printchar
            pushchar '-'
            call printchar
            pushchar '-'
            call printchar
            pushlocal i
            pushi32 1
            add
            setlocal i
        :lcond
            pushlocal game
            getfield Game:w
            pushlocal i
            lt
            jtrue lloop

            
        
        pushchar '\n'
        call printchar

        pushi64 1
        pushlocal y
        add
        setlocal y
    :ycond
        pushlocal game
        getfield Game:h
        pushlocal y
        conv i32
        lt
        jtrue yloop
    call flush
    ret
end
fn modval(val i32 max i32) i32
    pushi32 0
    pushlocal val
    lt
    not
    jtrue checkmax
        pushi32 1
        pushlocal max
        sub
        ret
    :checkmax
    pushlocal max
    pushlocal val
    eq
    not
    jtrue endl

    pushi32 0
    ret

    :endl
        pushlocal val
        ret
end
fn input(game *Game key char) void
    locals 
        w i32
        h i32
    end
    pushlocal game
    getfield Game:w
    setlocal w
    pushlocal game
    getfield Game:h
    setlocal h

    pushlocal key
    pushchar 'a'
    eq
    jtrue left
    pushlocal key
    pushchar 'd'
    eq
    jtrue right
    pushlocal key
    pushchar 'w'
    eq
    jtrue up
    pushlocal key
    pushchar 's'
    eq
    jtrue down
    
    jmp endl
    
    :left
        pushlocal w 

        pushi32 1
        pushlocal game
        getfield Game:selectedX
        sub

        call modval

        pushlocal game
        setfield Game:selectedX
        jmp endl
    :right
        pushlocal w 

        pushi32 1
        pushlocal game
        getfield Game:selectedX
        add
        
        call modval

        pushlocal game
        setfield Game:selectedX
        jmp endl
    :down
        pushlocal h

        pushi32 1
        pushlocal game
        getfield Game:selectedY
        add 

        call modval

        pushlocal game
        setfield Game:selectedY
        jmp endl
    :up
        pushlocal h

        pushi32 1
        pushlocal game
        getfield Game:selectedY
        sub 

        call modval

        pushlocal game
        setfield Game:selectedY
        jmp endl
        
    :endl
    ret
end

fn test(game *Game x i64 y i64) void
    locals 
        ix i64
        iy i64
        tx i64
        ty i64
    end
    pushi64 0
    pushlocal x
    lt
    jtrue outofbounds

    pushi64 0
    pushlocal y
    lt
    jtrue outofbounds

    pushlocal game
    getfield Game:w
    conv i64
    pushlocal x
    pushi64 1
    add
    gt
    jtrue outofbounds

    pushlocal game
    getfield Game:h
    conv i64
    pushlocal y
    pushi64 1
    add
    gt

    jtrue outofbounds
    pushlocal game
    getfield Game:board
    pushlocal y
    getindex
    pushlocal x
    getindexref
    getfield Cell:isTested
    jtrue outofbounds


    pushtrue
    pushlocal game
    getfield Game:board
    pushlocal y
    getindex
    pushlocal x
    getindexref
    getfieldref Cell:isTested
    storeref

    pushlocal game
    getfield Game:board
    pushlocal y
    getindex
    pushlocal x
    getindexref
    getfield Cell:isBomb
    jtrue outofbounds

   
    pushi64 -1
    setlocal iy
    :yloop
        pushi64 -1
        setlocal ix
        :xloop

            pushlocal iy
            pushlocal y
            add
            setlocal ty

            pushlocal ix
            pushlocal x
            add
            setlocal tx
            
            pushi32 0
            pushlocal ty
            pushlocal tx
            pushlocal game
            call getBombsAt
            gt
            jtrue incr 



            pushlocal ty
            pushlocal tx
            pushlocal game
            call test
            
            :incr
            pushlocal ty
            pushlocal tx
            pushlocal game
            call isBomb
            jtrue skipSettingTested
            pushlocal ty
            pushlocal tx
            pushlocal game
            call setTested
            :skipSettingTested

            pushlocal ix
            pushi64 1
            add
            setlocal ix
        :xcond
            pushi64 2
            pushlocal ix
            lt
            jtrue xloop
        pushlocal iy
        pushi64 1
        add 
        setlocal iy

    :ycond
        pushi64 2
        pushlocal iy
        lt
        jtrue yloop
    ;pushi32 0
    ;pop
    :outofbounds
    ret

    
end
fn setTested(game *Game x i64 y i64) void
    pushi64 0
    pushlocal x
    lt
    jtrue notabomb

    pushi64 0
    pushlocal y
    lt
    jtrue notabomb

    pushlocal game
    getfield Game:w
    conv i64
    pushlocal x
    pushi64 1
    add
    gt
    jtrue notabomb

    pushlocal game
    getfield Game:h
    conv i64
    pushlocal y
    pushi64 1
    add
    gt
    jtrue notabomb

    pushtrue
    pushlocal game
    getfield Game:board
    pushlocal y
    getindex
    pushlocal x
    getindexref
    setfield Cell:isTested
    ret

    :notabomb
        ret
end
fn getBombsAt(game *Game x i64 y i64) i32
    pushi64 0
    pushlocal x
    lt
    jtrue notabomb

    pushi64 0
    pushlocal y
    lt
    jtrue notabomb

    pushlocal game
    getfield Game:w
    conv i64
    pushlocal x
    pushi64 1
    add
    gt
    jtrue notabomb

    pushlocal game
    getfield Game:h
    conv i64
    pushlocal y
    pushi64 1
    add
    gt
    jtrue notabomb

    pushlocal game
    getfield Game:board
    pushlocal y
    getindex
    pushlocal x
    getindexref
    getfield Cell:bombsAround
    ret

    :notabomb
        pushi32 0
        ret
end
fn checkWin (game *Game) void 
    locals
        x i64
        y i64
        untested i32
    end
    :yloop
        pushi64 0
        setlocal x
        :xloop
            pushlocal game
            getfield Game:board
            pushlocal y
            getindex
            pushlocal x
            getindexref
            getfield Cell:isTested
            jtrue incr
            pushlocal untested
            pushi32 1
            add
            setlocal untested
            :incr
                pushi64 1
                pushlocal x
                add
                setlocal x
        :xcond
            pushlocal game
            getfield Game:w
            pushlocal x
            conv i32
            lt
            jtrue xloop
        pushi64 1
        pushlocal y
        add
        setlocal y
    :ycond
        pushlocal game
        getfield Game:h
        pushlocal y
        conv i32
        lt
        jtrue yloop

    pushlocal game
    getfield Game:numberOfBombs
    pushlocal untested
    eq
    not
    jtrue endoffn
    
    pushstr "YOU WIN"
    call println
    
    pushtrue
    pushlocal game
    setfield Game:gameOver


    :endoffn
    ret
end
fn update (game *Game key char) void 
    pushlocal key
    pushchar ' '
    eq 
    not
    jtrue endl
    
    pushlocal game
    getfield Game:selectedY
    conv i64
    pushlocal game
    getfield Game:selectedX
    conv i64
    pushlocal game
    call isBomb
    not
    jtrue test

    pushtrue
    pushlocal game
    setfield Game:gameOver
    pushstr "BOOM BOOM BOOM"
    call println
    :test 
    pushlocal game
    getfield Game:selectedY
    conv i64
    pushlocal game
    getfield Game:selectedX
    conv i64
    pushlocal game
    call test
    pushlocal game
    call checkWin

    :endl
    pushlocal key
    pushlocal game
    call input
    ret
end
fn main () void
    locals 
        g *Game
        key char
    end
    pushi32 9
    pushi32 10
    pushi32 10
    call newGame 
    box
    setlocal g
    pushlocal g
    call fillBoard
    :loop
        call clear
        pushlocal g
        call printBoard
        call getch
        setlocal key
        pushlocal key
        pushchar 'q'
        eq
        jtrue endl
        pushlocal key
        pushlocal g
        call update
    :lcond
        pushlocal g
        getfield Game:gameOver
        not
        jtrue loop
    :endl
    ret
end

