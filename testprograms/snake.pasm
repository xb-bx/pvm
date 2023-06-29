module snake 

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
import fn kbhit from builtins
import fn getch from builtins


type Point
    x i32
    y i32
end
type Snake 
    arr $Point
    count i64
end

type Game
    snake Snake
    width i32
    height i32
    size i32
    dir Point
    fruit Point
    gameOver bool
end

fn main() void 
    locals 
        game *Game
    end
    call clear

    pushi32 100    
    pushi32 15    
    pushi32 30   
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

    pushi32 70
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
    locals
        count i64
        arr $Point
    end
    pushlocal game
    getfieldref Game:snake
    getfield Snake:count
    setlocal count
    
    pushlocal count
    pushi64 1
    add
    pushlocal game
    getfieldref Game:snake
    setfield Snake:count
    
    
    ret

end

fn placeFruit (game *Game) void
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
    
    ret
end

fn createGame(w i32 h i32 size i32) *Game 
    locals
        snake Snake
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

    pushi64 100
    newobj $Point

    reflocal snake
    setfield Snake:arr
    

    pushi32 5
    reflocal snake
    getfield Snake:arr
    pushi64 0
    getindexref
    setfield Point:x
    
    pushi32 5
    reflocal snake
    getfield Snake:arr
    pushi64 0
    getindexref
    setfield Point:y

    pushi32 4
    reflocal snake
    getfield Snake:arr
    pushi64 1
    getindexref
    setfield Point:x
    
    pushi32 5
    reflocal snake
    getfield Snake:arr
    pushi64 1
    getindexref
    setfield Point:y
    
    pushi64 2
    reflocal snake
    setfield Snake:count

    
    pushlocal snake
    pushlocal game
    setfield Game:snake

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
        getfieldref Game:snake
        getfield Snake:arr
        pushlocal i
        getindex
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
        getfieldref Game:snake
        getfield Snake:count
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
        snake &Snake
        arr $Point
        cur &Point
        next &Point
        head &Point
    end
    
    pushlocal game
    getfieldref Game:snake
    setlocal snake 

    pushlocal snake
    getfield Snake:arr
    setlocal arr

    pushi64 1
    pushlocal snake
    getfield Snake:count
    sub
    setlocal i

    jmp cond
    :body
        pushlocal arr
        pushlocal i
        getindexref
        setlocal cur

        pushlocal arr
        pushi64 1
        pushlocal i
        sub
        getindexref
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

    pushlocal arr
    pushi64 0
    getindexref
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
        pushlocal arr
        pushlocal i
        getindexref
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
        getfield Snake:count
        pushlocal i
        lt
        jtrue cbody

    pushlocal head
    pushlocal game
    getfieldref Game:fruit
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
fn pointEq (p1 &Point p2 &Point) bool
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
        c char
    end

    call kbhit
    not
    jtrue none

    call getch
    setlocal c

    pushlocal c 
    pushchar 'a'
    eq
    jtrue left

    pushlocal c 
    pushchar 'd'
    eq
    jtrue right 
    
    pushlocal c 
    pushchar 'w'
    eq
    jtrue up 

    pushlocal c 
    pushchar 's'
    eq
    jtrue down
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
