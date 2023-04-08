module snakelist 



import List
import fn newList from List
import fn ListAppend from List
import type List from List

import builtins
import fn flush from builtins
import fn inspect from builtins
import fn printchar from builtins
import fn printi64 from builtins
import fn clear from builtins
import fn sleep from builtins
import fn getkeystate from builtins
import fn rand from builtins
import fn boolToI64 from builtins
import fn printi32 from builtins
import fn println from builtins
import fn gcmem from builtins


type Point
    x i32
    y i32
end

type Game
    snake *List
    width i32
    height i32
    size i32
    dir Point
    fruit Point
    gameOver bool
end
fn printPoint(p *Point) void
    pushstr "x = "
    call println
    pushlocal p
    getfield Point:x
    call printi32

    pushstr "y = "
    call println
    pushlocal p
    getfield Point:y
    call printi32

    ret
    
end

fn main() void 
    locals 
        game *Game
        before i64
    end
    call clear

    pushi32 100    
    pushi32 20    
    pushi32 60   
    call createGame
    setlocal game

    pushlocal game
    pushlocal game
    pushlocal game
    getfield Game:width
    call printi32
    getfield Game:height
    call printi32
    getfield Game:size
    call printi32

    pushi32 5
    pushi32 5
    pushlocal game
    call checkSnake
    call boolToI64
    pop

    :llop
    call gcmem
    setlocal before
    pushlocal game
    call input
    pushlocal game
    call move
    call clear    

    
    pushlocal game
    getfieldref Game:fruit
    getfield Point:x
    call printi32
    pushlocal game
    getfieldref Game:fruit
    getfield Point:y
    call printi32
    
    pushlocal game
    call printmap

    call gcmem
    pushlocal before
    sub
    call printi64
    call gcmem 
    call printi64
    pushi32 50
    call sleep
    pushlocal game
    getfield Game:gameOver
    not
    jtrue llop
    
    pushstr "GAME OVER. LOSER\n"
    call println

    ret

end

fn grow (game *Game) void
    pushlocal game
    getfield Game:snake
    getfield List:objects
    pushi64 0
    getindex
    cast *Point
    unbox
    box
    cast any
    
    pushlocal game
    getfield Game:snake

    call ListAppend

    ret

end

fn placeFruit (game *Game) void
    :st
    pushi32 1
    pushlocal game
    getfield Game:width
    sub
    conv i64
    pushi64 1
    call rand
    conv i32
    pushlocal game
    getfieldref Game:fruit
    setfield Point:x

    pushi32 1
    pushlocal game
    getfield Game:height
    sub
    conv i64
    pushi64 1
    call rand
    conv i32
    pushlocal game
    getfieldref Game:fruit
    setfield Point:y

    pushlocal game
    getfieldref Game:fruit
    getfield Point:y

    pushlocal game
    getfieldref Game:fruit
    getfield Point:x
    
    pushlocal game
    call checkSnake
    jtrue st

    ret
end

fn newPoint(x i32 y i32) Point
    locals
        p Point
    end
    pushlocal x
    reflocal p
    setfield Point:x
    pushlocal y
    reflocal p
    setfield Point:y
    
    pushlocal p
    ret
end

fn createGame(w i32 h i32 size i32) *Game 
    locals
        g Game
        game *Game
    end
    pushlocal g
    box 
    setlocal game

    pushi32 1
    pushlocal game
    getfieldref Game:dir
    setfield Point:y

    pushi64 4
    call newList
    pushlocal game
    setfield Game:snake

    pushi32 1
    pushi32 5
    call newPoint
    box
    cast any

    pushlocal game
    getfield Game:snake
    call ListAppend
    
    pushi32 0
    pushi32 5
    call newPoint
    box
    cast any

    pushlocal game
    getfield Game:snake
    call ListAppend
    
    pushi32 0
    pushi32 5
    call newPoint
    box
    cast any

    pushlocal game
    getfield Game:snake
    call ListAppend
    
    pushi32 0
    pushi32 5
    call newPoint
    box
    cast any

    pushlocal game
    getfield Game:snake
    call ListAppend

    
    pushi32 5
    pushi32 5
    call newPoint
    box
    cast any

    pushlocal game
    getfield Game:snake
    call ListAppend


    
    pushlocal w
    pushlocal game
    setfield Game:width
    

    pushlocal h
    pushlocal game
    setfield Game:height
    
    pushlocal size
    pushlocal game
    setfield Game:size
    
    pushlocal game
    call placeFruit

    pushlocal game 
    ret
end
fn checkSnake (game *Game x i32 y i32) bool 
    locals
        i i64
        p Point
    end 
    jmp cond
    :body 
        pushlocal game
        getfield Game:snake
        getfield List:objects
        pushlocal i
        getindex
        cast *Point
        unbox
        setlocal p
        
        reflocal p
        getfield Point:x
        pushlocal x
        eq
        not
        jtrue nextit
        reflocal p
        getfield Point:y
        pushlocal y
        eq
        not
        jtrue nextit

        pushtrue
        ret
        
        :nextit
        pushlocal i
        pushi64 1
        add
        setlocal i
    :cond
        pushlocal game
        getfield Game:snake
        getfield List:count
        pushlocal i
        lt
        jtrue body

    pushfalse
    ret

end
fn booland(b1 bool b2 bool) bool 
    pushlocal b1
    not 
    jtrue endif
    pushlocal b2
    not
    jtrue endif
    pushtrue
    ret
    :endif
    pushfalse
    ret
end
fn printmap(game *Game) void 
    locals 
        x i32
        y i32
        fruit &Point
    end
    pushlocal game
    getfieldref Game:fruit
    setlocal fruit
    jmp ycond
    :ybody
        pushi32 0
        setlocal x
        jmp xcond
        :xbody
            pushlocal y
            pushlocal x
            pushlocal game
            call checkSnake
            jtrue snk

            pushlocal fruit
            getfield Point:x
            pushlocal x
            eq

            pushlocal fruit
            getfield Point:y
            pushlocal y
            eq
            call booland
            jtrue zero 
            pushi32 0
            pushlocal x
            eq
            jtrue zero
            pushi32 0
            pushlocal y
            eq 
            jtrue zero
            pushi32 1
            pushlocal game
            getfield Game:height
            sub
            pushlocal y
            eq 
            jtrue zero
            pushi32 1
            pushlocal game
            getfield Game:width
            sub
            pushlocal x
            eq 
            jtrue zero
                pushchar ' '
                call printchar
                jmp endif
            :snk
                pushchar '0'
                call printchar
                jmp endif
            :zero
                pushchar '#'
                call printchar
            :endif

            pushi32 1
            pushlocal x
            add
            setlocal x
        :xcond 
            pushlocal game
            getfield Game:width
        
            pushlocal x
        
            lt
            jtrue xbody
        
        pushchar '\n'
        call printchar

        pushlocal y
        pushi32 1
        add
        setlocal y
    :ycond
        pushlocal game
        getfield Game:height
    
        pushlocal y
    
        lt
        jtrue ybody
    call flush     
    ret
end

fn move(game *Game) void
    locals 
        i i64
        cur *Point
        next *Point
        head *Point
        snake *List
    end
    
    pushlocal game
    getfield Game:snake
    setlocal snake 


    pushi64 1
    pushlocal snake
    getfield List:count
    sub
    setlocal i

    jmp cond
    :body
        pushlocal snake
        getfield List:objects
        pushlocal i
        getindex
        cast *Point
        setlocal cur

        pushlocal snake
        getfield List:objects
        pushi64 1
        pushlocal i
        sub
        getindex
        cast *Point
        setlocal next

        pushlocal next
        getfield Point:x
        pushlocal cur
        setfield Point:x

        pushlocal next
        getfield Point:y
        pushlocal cur
        setfield Point:y
        
        pushi64 1
        pushlocal i
        sub
        setlocal i
    :cond
        pushi64 0
        pushlocal i
        gt
        jtrue body

    pushlocal snake
    getfield List:objects
    pushi64 0
    getindex
    cast *Point
    setlocal head

    pushlocal game
    getfieldref Game:dir
    getfield Point:x
    pushlocal head
    getfield Point:x
    add
    pushlocal head
    getfieldref Point:x
    storeref

    pushlocal game
    getfieldref Game:dir
    getfield Point:y
    pushlocal head
    getfield Point:y
    add
    pushlocal head
    getfieldref Point:y
    storeref

    pushlocal head
    getfield Point:x
    
    pushi32 2
    pushlocal game
    getfield Game:width
    sub
    lt
    jtrue xtozero
    
    pushlocal head
    getfield Point:x

    pushi32 0
    eq
    jtrue xtoend

    jmp endif  
    :xtozero
        pushi32 1
        pushlocal head
        getfieldref Point:x
        storeref
        jmp endif
    :xtoend
        pushi32 2
        pushlocal game
        getfield Game:width
        sub
        pushlocal head
        setfield Point:x
        jmp endif
    :endif

    pushlocal head
    getfield Point:y
    
    pushi32 2
    pushlocal game
    getfield Game:height
    sub
    lt
    jtrue ytozero
    
    pushlocal head
    getfield Point:y

    pushi32 0
    eq
    jtrue ytoend

    jmp yendif  
    :ytozero
        pushi32 1
        pushlocal head
        getfieldref Point:y
        storeref
        jmp endif
    :ytoend
        pushi32 2
        pushlocal game
        getfield Game:height
        sub
        pushlocal head
        setfield Point:y
        jmp endif
    :yendif

    pushi64 1
    setlocal i
    jmp ccond
    :cbody
        pushlocal snake
        getfield List:objects
        pushlocal i
        getindex
        cast *Point
        pushlocal head
        call pointEq
        not 
        jtrue nextit
   
        pushtrue
        pushlocal game 
        setfield Game:gameOver

        :nextit
            pushlocal i
            pushi64 1
            add
            setlocal i

    :ccond
        pushlocal snake
        getfield List:count
        pushlocal i
        lt
        jtrue cbody

    pushlocal head
    pushlocal game
    getfield Game:fruit
    box
    call pointEq
    not
    jtrue endmethod
    pushlocal game
    call placeFruit
    pushlocal game
    call grow

    


    :endmethod
    ret
end
fn pointEq (p1 *Point p2 *Point) bool
    pushlocal p1
    getfield Point:x
    pushlocal p2
    getfield Point:x
    eq
    pushlocal p1
    getfield Point:y
    pushlocal p2
    getfield Point:y
    eq
    call booland
    ret
end
fn input(game *Game) void
    locals 
        left i64
        up i64
        right i64
        down i64
    end
    pushi64 37
    setlocal left
    pushi64 38
    setlocal up
    pushi64 39
    setlocal right 
    pushi64 40
    setlocal down
    
    pushlocal left
    call getkey
    jtrue left
    pushlocal right
    call getkey
    jtrue right 
    pushlocal up 
    call getkey
    jtrue up 
    pushlocal down 
    call getkey
    jtrue down
    pushi64 32
    call getkey
    jtrue sp
    jmp none
    :left
        pushlocal game 
        getfieldref Game:dir
        getfield Point:x
        pushi32 1
        eq
        jtrue endswitch
        pushi32 -1
        pushlocal game
        getfieldref Game:dir
        setfield Point:x
        
        pushi32 0
        pushlocal game
        getfieldref Game:dir
        setfield Point:y

        jmp endswitch
    :right
        pushlocal game 
        getfieldref Game:dir
        getfield Point:x
        pushi32 -1
        eq
        jtrue endswitch
        pushi32 1
        pushlocal game
        getfieldref Game:dir
        setfield Point:x
        
        pushi32 0
        pushlocal game
        getfieldref Game:dir
        setfield Point:y
        jmp endswitch
    :up
        pushlocal game 
        getfieldref Game:dir
        getfield Point:y
        pushi32 1
        eq
        jtrue endswitch

        pushi32 0
        pushlocal game
        getfieldref Game:dir
        setfield Point:x
        
        pushi32 -1
        pushlocal game
        getfieldref Game:dir
        setfield Point:y
        jmp endswitch
    :down
        pushlocal game 
        getfieldref Game:dir
        getfield Point:y
        pushi32 -1
        eq
        jtrue endswitch

        pushi32 0
        pushlocal game
        getfieldref Game:dir
        setfield Point:x
        
        pushi32 1
        pushlocal game
        getfieldref Game:dir
        setfield Point:y
    
        jmp endswitch
    :sp
        pushlocal game
        call grow

    :none
    :endswitch

    ret
end
fn getkey(key i64) bool 
    pushi64 0
    pushlocal key
    call getkeystate
    eq
    not
    ret
end
