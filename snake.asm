assume cs:code, ds:data, ss:stack

stack segment
    db 128 dup (0)
stack ends

; snake 存储蛇身每个单元格的在内存中的位置 (保存每个蛇身格左边字符的颜色单元)
; head 存储蛇头的位置
; tail 存储蛇尾的位置
; food 存储 食物的坐标
; status 存储蛇的状态
; 0: 1 表示活, 0 表示蛇死
; 1,2: 00, 01, 10, 11 表示 上、右、下、左
; 3,4: 00, 01, 10, 11 表示不同的速度等级
; 5: 1 表示吃到食物, 0 表示没吃到食物
; 6: 0 表示还没赢, 1 表示赢 (长度达到512)
data segment
    snake dw 512 dup (0)
    head dw 0
    tail dw 0
    score dw 0
    food dw 0
    str_score db 'score: ',0
    str_author db 'author:Neroll',0
    str_version db 'version:1.0',0
    str_gameover db 'Game Over',0
    str_win db 'You Win',0
    str_win_tip db 'Congratulations!',0
    str_tip1 db 'press ENTER to play again',0
    str_tip2 db 'press ESC to quit',0
    tmp_str db 32 dup (0)
    tmp_tail dw 0
    int9 dw 0,0
    round dw 0
    str_eat db 'You have eaten yourself',0
    str_clash_u db 'You crashed the up wall',0
    str_clash_l db 'You crashed the left wall',0
    str_clash_r db 'You crashed the right wall',0
    str_clash_b db 'You crashed the bottom wall',0
data ends

code segment
start:  cli
        
        mov ax,stack
        mov ss,ax
        mov sp,128

        mov ax,data
        mov ds,ax

        mov cx,2000h
        mov ah,01h
        int 10h                 ; 调用 int 10h 中断例程隐藏光标

        call installInt9

gbegin: call setInt9

        call clearBuffer

        call clearScreen        ; 清空屏幕

        ; mov cl,05h
        ; call delay

        call initGame           ; 初始化蛇身和食物位置

        call paintFrame         ; 打印游戏边界和分数面板

        call printSnake

gloop:  inc round
        call calculate         ; 计算蛇移动后的位置

        call checkStatus       ; 判断当前蛇的状态, 会改变 al 的值

        mov bl,al
        and bl,00000001b
        cmp bl,0
        je dead                 ; 如果蛇死亡, 游戏结束

        

        mov bl,al
        and bl,00100000b
        cmp bl,00100000b
        jne jwin                ; 判断是否吃到食物, 如果没吃到就跳过 addlen
        ;call addlen             ; 如果吃到食物, 增加长度
        call eatFood


jwin:   mov bl,al
        and bl,01000000b
        cmp bl,01000000b
        je win                  ; 判断是否胜利

        call updateScreen

pause:  

        ; push dx
        ; mov dx,round
        ; call debug
        ; pop dx

        mov cl,02h              ; cl 存储停顿的时间
        call delay               ; 停顿一段时间, 此时接受键盘输入

        ; push dx
        ; mov dx,head
        ; call debug
        ; pop dx

        ; push dx
        ; push ax
        ; push bx
        ; mov bx,head
        ; sub bx,2
        ; and bx,01ffh
        ; mov bx,snake[bx]
        ; mov ax,bx
        ; mov bl,160
        ; div bl
        ; mov dh,0
        ; mov dl,ah
        ; call debug
        ; pop bx
        ; pop ax
        ; pop dx
        
        and al,01111111b

        jmp gloop               ; 进入下一轮


dead:    

        call gameOver           ; 打印 Game Over, 按 ENTER 重新开始, 按 ESC 退出

        

        cmp dl,1                ; gameOver 要保证 dl 要么为 1 (ESC), 要么为 1ch (ENTER)
        jne gbegin
        jmp gend

win:    ;call updateScreen
        call youWin             ; 打印 You Win, 按 ENTER 重新开始, 按 ESC 退出
        cmp dl,1                ; youWin 要保证 dl 要么为 1 (ESC), 要么为 1ch (ENTER)
        jne gbegin


gend:   mov ah,01h
        mov ch,0ah
        mov cl,0ch
        int 10h                 ; 调用 int 10h 中断例程显示光标

        call loadInt9
        sti
        mov ax,4c00h
        int 21h

        ; clearBuffer BEGIN -------------------------------------
        ; 名称: clearBuffer
        ; 参数: 无
        ; 功能: 清空键盘缓冲区

        clearBuffer:    push ax
                        push bx

        clearBuffers:   mov ah,1
                        int 16h

                        jz clearBufferret
                        mov ah,0
                        int 16h

                        ;call clearScreen
                        ;call crash

                        jmp clearBuffers

        clearBufferret: pop bx
                        pop ax
                        ret


        ; clearBuffer END ---------------------------------------


        ; clearScreen BEGIN -------------------------------------
        ; 名称: clearScreen
        ; 参数: 无
        ; 功能: 清空屏幕上所有字符

        clearScreen:    push es
                        push bx
                        push cx

                        mov bx,0b800h
                        mov es,bx
                        
                        mov bx,0
                        mov cx,2000
        clscreens:      mov byte ptr es:[bx],' '
                        mov byte ptr es:[bx+1],0
                        add bx,2
                        loop clscreens

                        pop cx
                        pop bx
                        pop es
                        ret
        ; clearScreen END -------------------------------------


        ; delay BEGIN ---------------------------------------
        ; 名称: delay
        ; 参数: cl 表示循环次数
        ; 功能: 进行空循环使游戏停顿一段时间

        delay:  push bx
                push dx

                mov bx,0
                mov dh,0
                mov dl,cl

                sti
        delays: sub bx,1
                sbb dx,0
                cmp bx,0
                jne delays
                cmp dx,0
                jne delays

                cli
                pop dx
                pop bx
                ret
        ; delay END ---------------------------------------


        ; eatFood BEGIN -----------------------------------
        ; 名称: eatFood
        ; 参数: 无
        ; 功能: 使蛇尾保持不变, 重置状态字节的食物位, 重新生成食物

        eatFood:    push bx
                    push es

                    mov bx,0b800h
                    mov es,bx

                    sub tail,2
                    and tail,01ffh
                    mov bx,tail
                    mov bx,snake[bx]
                    mov byte ptr es:[bx],01110000b
                    mov byte ptr es:[bx+2],01110000b
                    and al,11011111b
                    call createFood

                    pop es
                    pop bx
                    ret
        ; eatFood END -------------------------------------


        ; printSnake BEGIN -------------------------------
        ; 名称: printSnake
        ; 参数: 无
        ; 功能: 打印蛇

        printSnake: push es
                    push di
                    push bx

                    mov bx,0b800h
                    mov es,bx

                    mov bx,head
                    sub bx,4
                    and bx,01ffh

        printSlp:   mov di,snake[bx]
                    mov byte ptr es:[di],01110000b
                    mov byte ptr es:[di+2],01110000b
                    sub bx,2
                    and bx,01ffh
                    cmp bx,tail
                    jne printSlp

                    mov bx,head
                    sub bx,2
                    and bx,01ffh
                    mov bx,snake[bx]
                    
                    mov byte ptr es:[bx],00110000b
                    mov byte ptr es:[bx+2],00110000b

                    pop bx
                    pop di
                    pop es
                    ret
        ; printSnake END ---------------------------------


        ; initGame BEGIN ----------------------------------
        ; 名称: initGame
        ; 参数: 无
        ; 功能: 计算蛇和食物一开始的位置

        initGame:   push si
                    push bx
                    push cx

                    mov bx,0
                    mov si,160*19+2*6+1
                    mov cx,4
        paintInitS: mov word ptr snake[bx],si
                    add si,4
                    add bx,2
                    loop paintInitS

                    mov head,8
                    mov tail,0
                    mov ah,0
                    mov al,00000011b    ; al 中存储状态
                    mov score,0
                    call createFood

                    mov round,0

                    pop cx
                    pop bx
                    pop si
                    ret
        ; initGame END ------------------------------------


        ; debug BEGIN -------------------------------------
        ; 名称: debug
        ; 参数: dx 存储要显示的数据
        ; 功能: 显示 dx 中的数据
        debug:      push si
                    push cx
                    
                    mov si,offset tmp_str
                    call wtoc
                    push dx
                    mov dh,2
                    mov dl,3
                    mov cl,7
                    call showStr
                    pop dx
                    pop cx
                    pop si
                    ret
        ; debug END ---------------------------------------


        ; updated
        ; createFood BEGIN ----------------------------------
        ; 名称: createFood
        ; 参数: 无
        ; 功能: 在地图内随机生成食物, 且食物不会与蛇重叠

        createFood: push ax
                    push bx
                    push dx
                    push cx
                    push es

                    mov bx,0b800h
                    mov es,bx

        cratfod:    mov ah,0
                    mov al,0
                    out 40h,al
                    in al,40h
                    in al,40h
                    in al,40h
                    in al,40h
                    mov bl,23
                    div bl
                    inc ah
                    mov al,ah

                    mov ah,0
                    mov bx,ax
                    mov cl,7
                    shl ax,cl

                    mov cl,5
                    shl bx,cl

                    add ax,bx

                    mov dx,ax

                    mov al,0
                    out 40h,al
                    in al,40h
                    in al,40h
                    in al,40h
                    in al,40h
                    mov bl,45
                    div bl
                    add ah,2
                    mov al,ah
                    mov ah,0

                    mov bx,ax
                    and bx,1
                    cmp bx,1
                    jne concalc
                    inc ax

        concalc:    shl ax,1

                    add dx,ax
                    inc dx

                    mov bx,dx
                    mov bl,es:[bx]
                    cmp bl,01110000b
                    je cratfod
                    cmp bl,00110000b
                    je cratfod
                    cmp cl,00010000b

                    mov food,dx
                    pop es
                    pop cx
                    pop dx
                    pop bx
                    pop ax
                    ret
        ; createFood END ------------------------------------


        ; paintFrame BEGIN --------------------------------
        ; 名称: paintFrame
        ; 参数: 无
        ; 功能: 打印游戏边框和分数面板

        paintFrame: push es
                    push bx
                    push cx
                    push dx
                    push si

                    mov bx,0b800h
                    mov es,bx

                    mov bx,1
                    mov cx,25
        paintups:   mov byte ptr es:[bx],01000000b
                    mov byte ptr es:[bx+2],01000000b
                    add bx,4
                    loop paintups

                    mov bx,1
                    mov cx,25
        paintlfs:   mov byte ptr es:[bx],01000000b
                    mov byte ptr es:[bx+2],01000000b
                    add bx,160
                    loop paintlfs

                    mov bx,2*48+1
                    mov cx,25
        paintrts:   mov byte ptr es:[bx],01000000b
                    mov byte ptr es:[bx+2],01000000b
                    add bx,160
                    loop paintrts

                    mov bx,160*24+1
                    mov cx,25
        paintdns:   mov byte ptr es:[bx],01000000b
                    mov byte ptr es:[bx+2],01000000b
                    add bx,4
                    loop paintdns

                    mov dh,0
                    mov dl,51
                    mov cl,7
                    mov si,offset str_score
                    call showStr            ; 显示 'score: '

                    mov si,offset tmp_str
                    mov dx,0
                    call wtoc

                    mov dh,0
                    mov dl,58
                    mov cl,7
                    call showStr            ; 显示当前分数

                    mov dh,24
                    mov dl,51
                    mov cl,7
                    mov si,offset str_author
                    call showStr            ; 显示作者

                    mov dl,67
                    mov si,offset str_version
                    call showStr            ; 显示版本

        paintfret:  pop si
                    pop dx
                    pop cx
                    pop bx
                    pop es
                    ret
        ; paintFrame END ---------------------------------


        ; updated
        ; calculate BEGIN --------------------------------
        ; 名称: calculate
        ; 参数: 无
        ; 功能: 计算蛇移动后的位置

        calculate:  push bx
                    push si
                    push es
                    push dx

                    mov bx,0b800h
                    mov es,bx

                    ; mov bx,tail
                    ; mov bx,snake[bx]
                    ; and byte ptr es:[bx],0
                    ; mov byte ptr es:[bx+2],0
                    ; add tail,2
                    ; and tail,01ffh

        calcpos:    mov si,head
                    sub si,2
                    and si,01ffh
                    mov dx,snake[si]

                    mov bx,ax
                    shr bl,1
                    and bl,00000011b

                    cmp bl,0
                    je moveUp

                    cmp bl,1
                    je moveRight

                    cmp bl,2
                    je moveDown

                    cmp bl,3
                    je moveLeft

                    jmp calcret

        moveUp:     sub dx,160
                    jmp calcret

        moveRight:  add dx,4
                    jmp calcret

        moveDown:   add dx,160
                    jmp calcret

        moveLeft:   sub dx,4
                    jmp calcret


        calcret:    add si,2
                    and si,01ffh
                    mov snake[si],dx

                    add head,2
                    and head,01ffh

                    pop dx
                    pop es
                    pop si
                    pop bx
                    ret
        ; calculate END ----------------------------------


        ; updated
        ; checkStatus BEGIN ------------------------------
        ; 名称: checkStatus
        ; 参数: 无
        ; 返回: 返回新的蛇的状态字节, 存储在 al 中, 会覆盖掉原来的状态字节
        ; 功能: 更新蛇的状态字节, 包括 判断蛇当前是否吃到食物,
        ;       当前是否胜利, 当前是否死亡, 根据当前长度判断当前速度
        checkStatus:    push bx
                        push cx
                        push di
                        push es
                        push dx

                        mov bx,0b800h
                        mov es,bx

                        mov cx,ax

                        mov bx,head
                        sub bx,tail
                        shr bx,1
                        add bx,512
                        and bx,01ffh

                        cmp bx,11
                        jna judgefood
                        and cl,11100111b
                        or cl, 00001000b    ; 如果长度大于 11, 提高速度

                        cmp bx,25
                        jna judgefood
                        and cl,11100111b
                        or cl, 00010000b    ; 如果长度大于 25, 提高速度

                        cmp bx,40
                        jna judgefood
                        and cl,11100111b
                        or cl, 00011000b    ; 如果长度大于 40, 提高速度

        judgefood:      mov bx,head
                        sub bx,2
                        and bx,01ffh

                        mov di,food
                        cmp snake[bx],di
                        jne judgelife
                        or cl,00100000b
                        add score,10

        judgelife:      mov ax,snake[bx]
                        dec ax
                        mov bl,160
                        div bl

                        cmp al,0
                        jne csbottom

                        ; push dx
                        ; push cx
                        ; push si
                        ; mov dh,5
                        ; mov dl,7
                        ; mov cl,3
                        ; mov si,offset str_clash_u
                        ; call showStr
                        ; pop si
                        ; pop cx
                        ; pop dx

                        ; je bedead
                        jmp bedead

        csbottom:       cmp al,24
                        jne csleft

                        ; push dx
                        ; push cx
                        ; push si
                        ; mov dh,5
                        ; mov dl,7
                        ; mov cl,3
                        ; mov si,offset str_clash_b
                        ; call showStr
                        ; pop si
                        ; pop cx
                        ; pop dx

                        ; je bedead
                        jmp bedead

        csleft:         shr ah,1
                        cmp ah,1

                        ja csright

                        ; push dx
                        ; push cx
                        ; push si
                        ; mov dh,5
                        ; mov dl,7
                        ; mov cl,3
                        ; mov si,offset str_clash_l
                        ; call showStr
                        ; pop si
                        ; pop cx
                        ; pop dx

                        ; jna bedead
                        jmp bedead


        csright:        cmp ah,48

                        jb csgethead

                        

                        ; push dx
                        ; push cx
                        ; push si
                        ; mov dh,5
                        ; mov dl,7
                        ; mov cl,3
                        ; mov si,offset str_clash_r
                        ; call showStr
                        ; pop si
                        ; pop cx
                        ; pop dx

                        ;jnb bedead
                        jmp bedead

        csgethead:      mov di,head
                        sub di,2
                        and di,01ffh
                        mov di,snake[di]

        eatself:        cmp byte ptr es:[di],01110000b

                        jne judgewin

                        ; push dx
                        ; push cx
                        ; push si
                        ; mov dh,5
                        ; mov dl,7
                        ; mov cl,3
                        ; mov si,offset str_eat
                        ; call showStr
                        ; pop si
                        ; pop cx
                        ; pop dx

                        ;je bedead
                        jmp bedead

        judgewin:       cmp dx,511
                        jna removetail
                        or cl,01000000b
                        jmp removetail

        bedead:         and cl,11111110b

        removetail:     mov bx,cx
                        and bl,1
                        cmp bl,0
                        je checkStatusret

                        mov bx,tail
                        mov bx,snake[bx]
                        and byte ptr es:[bx],0
                        mov byte ptr es:[bx+2],0
                        add tail,2
                        and tail,01ffh
         
        checkStatusret: mov ax,cx
                        pop dx
                        pop es
                        pop di
                        pop cx
                        pop bx
                        ret
        ; checkStatus END --------------------------------



        ; updated
        ; updateScreen BEGIN -----------------------------
        ; 名称: updateScreen
        ; 参数: 无
        ; 功能: 更新屏幕上显示的蛇, 食物, 分数
        updateScreen:   push bx
                        push es
                        push cx
                        push dx
                        push di

                        mov bx,0b800h
                        mov es,bx

                        mov bx,tail
                        sub bx,2
                        and bx,01ffh
                        mov bx,snake[bx]

                        mov byte ptr es:[bx],0
                        mov byte ptr es:[bx+2],0

                        mov bx,head
                        sub bx,2
                        and bx,01ffh
                        mov di,bx
                        mov bx,snake[bx]
                        sub di,2
                        and di,01ffh
                        mov di,snake[di]

                        mov byte ptr es:[di],01110000b
                        mov byte ptr es:[di+2],01110000b

                        mov byte ptr es:[bx],00110000b
                        mov byte ptr es:[bx+2],00110000b

                        mov bx,food
                        mov byte ptr es:[bx],00100000b
                        mov byte ptr es:[bx+2],00100000b

                        mov si,offset tmp_str
                        mov dx,score
                        call wtoc

                        mov dh,0
                        mov dl,58
                        mov cl,7
                        call showStr

                        pop di
                        pop dx
                        pop cx
                        pop es
                        pop bx
                        ret
        ; updateScreen END -------------------------------



        ; gameOver BEGIN ---------------------------------
        ; 名称: gameOver
        ; 参数: 无
        ; 功能: 显示游戏结束标语, 提示用户进行操作, 并获得用户的输入
        ; 返回: dl 中返回用户按键的通码
        gameOver:   push si
                    push ax
                    push cx
                    push dx

                    mov si,offset str_gameover
                    mov dh,11
                    mov dl,60
                    mov cl,7
                    call showStr

                    mov si,offset str_tip1
                    mov dh,12
                    mov dl,52
                    call showStr

                    mov si,offset str_tip2
                    mov dh,13
                    mov dl,56
                    call showStr

                    call loadInt9

                    pop dx      ; 由于 dl 要被修改, 所以提前弹出 dx

        ggloop:     mov ah,0
                    int 16h
                    cli
                    mov dl,ah
                    cmp dl,1
                    je ggret
                    cmp dl,1ch
                    je ggret
                    jmp ggloop

        ggret:      ;cli
                    pop cx
                    pop ax
                    pop si
                    ret
        ; gameOver END -----------------------------------


        ; youWin BEGIN -----------------------------------
        ; 名称: youWin
        ; 参数: 无
        ; 功能: 显示游戏结束标语, 提示用户进行操作, 并获得用户的输入
        ; 返回: dl 中返回用户按键的通码
        youWin:     push si
                    push ax
                    push cx
                    push dx

                    mov si,offset str_win
                    mov dh,11
                    mov dl,60
                    mov cl,7
                    call showStr

                    mov si,offset str_win_tip
                    mov dh,12
                    mov dl,56
                    call showStr

                    mov si,offset str_tip1
                    mov dh,13
                    mov dl,52
                    call showStr

                    mov si,offset str_tip2
                    mov dh,14
                    mov dl,56
                    call showStr

                    call loadInt9

                    pop dx      ; 由于 dl 要被修改, 所以提前弹出 dx

        winloop:    mov ah,0
                    int 16h
                    cli
                    mov dl,ah
                    cmp dl,1
                    je winret
                    cmp dl,1ch
                    je winret
                    jmp winloop

        winret:     ;cli
                    pop cx
                    pop ax
                    pop si
                    ret
        ; youWin END -------------------------------------



        ; addlen BEGIN -----------------------------------
        ; 名称: addlen
        ; 参数: 无
        ; 功能: 增加蛇的长度
        addlen:     push bx
                    push dx
                    
                    sub tail,2
                    and tail,01ffh
                    mov bx,tail

                    push tmp_tail
                    pop snake[bx]

                    mov dx,bx
                    mov bx,head
                    sub bx,dx
                    and bx,01ffh
                    cmp bx,511
                    jna addlenret
                    or al,01000000b

                    ;sub bx,head
                    ;and bx,01ffh
                    ;cmp bx,511
                    ;jna addlenret
                    ;or al,01000000b

        addlenret:  pop dx
                    pop bx
                    ret
        ; addlen END -------------------------------------



        ; wtoc BEGIN -------------------------------------
        ; 名称: wtoc
        ; 参数: dx word 型数据
        ;       ds:si 指向字符串的首地址
        ; 功能: 将 word 型数据转变为表示十进制的字符串, 字符串以0为结尾符

        wtoc:   push si
                push dx
                push ax
                push di
                push cx
                push bx

                mov di,0        ; di 用来计算栈内压入了多少数据

                mov ax,dx
                mov dx,0
                mov bx,10

        divsl:  div bx
                push dx
                inc di
                mov dx,0
                mov cx,ax
                jcxz outstr
                jmp divsl


        outstr: mov cx,di
        outstrs:pop ax
                add al,30h
                mov byte ptr ds:[si],al
                inc si
                loop outstrs

                mov byte ptr ds:[si],0      ; 字符串以0结尾

                pop bx
                pop cx
                pop di
                pop ax
                pop dx
                pop si
                ret
        ; wtoc END ---------------------------------------


        ; installInt9 BEGIN ---------------------------------
        ; 名称: installInt9
        ; 参数: 无
        ; 功能: 将 keyPress 复制到 0:200 中,
        ;       将 0:36, 0:38 中的地址改为 0:200

        installInt9:push bx
                    push es

                    call clearBuffer

                    mov bx,0
                    mov es,bx

                    push es:[9*4]
                    pop int9[0]
                    push es:[9*4+2]
                    pop int9[2]      ; 保存原来 int 9 中断例程的地址

                    mov word ptr es:[9*4],offset keyPress
                    mov word ptr es:[9*4+2],cs

                    pop es
                    pop bx
                    ret
        ; installInt9 END -----------------------------------



        ; showStr BEGIN ----------------------------------
        ; 名称: showStr
        ; 参数: dh 行号(0~24), dl 列号(0~79)
        ;       cl 颜色, ds:si 指向字符串首地址
        ; 功能: 在指定位置, 用指定颜色, 显示一个用0结尾的字符串

        showStr:    push es
                    push bx
                    push ax
                    push cx
                    push si

                    mov bx,0b800h
                    mov es,bx

                    mov ax,160
                    mul dh
                    mov bx,ax

                    mov al,cl

                    mov ch,0
                    mov cl,dl
                    add cx,cx
                    add bx,cx

                    mov ch,0
        showsloop:  mov cl,ds:[si]
                    jcxz showStrret
                    mov es:[bx],cl
                    mov es:[bx+1],al
                    inc si
                    add bx,2
                    jmp showsloop

        showStrret: pop si
                    pop cx
                    pop ax
                    pop bx
                    pop es
                    ret
        ; showStr END ------------------------------------

        


        ; saveInt9 BEGIN ------------------------------------
        ; 名称: saveInt9
        ; 参数: 无
        ; 功能: 保存原本 int 9 中断例程的地址
        ;saveInt9:   push es
                    ;push bx

                    ;mov bx,0
                    ;mov es,bx
                    ;push es:[9*4]
                    ;pop int9[bx]
                    ;push es:[9*4+2]
                    ;pop int9[bx+2]          ; 保存原来 int 9 中断例程的地址

                    ;pop bx
                    ;pop es
                    ;ret
        ; saveInt9 END --------------------------------------



        ; loadInt9 BEGIN ------------------------------------
        ; 名称: loadInt9
        ; 参数: 无
        ; 功能: 恢复原本 int 9 中断例程的地址
        loadInt9:   push es
                    push bx
                    
                    mov bx,0
                    mov es,bx
                    push int9[0]
                    pop es:[9*4]
                    push int9[2]          
                    pop es:[9*4+2]     ; 恢复原来 int 9 中断例程的地址

                    pop bx
                    pop es
                    ret
        ; loadInt9 END --------------------------------------

        ; setInt9 BEGIN -------------------------------------
        ; 名称: setInt9
        ; 参数: 无
        ; 功能: 将 0:36, 0:38 的值设置为 200h, 0
        setInt9:    push bx
                    push es

                    mov bx,0
                    mov es,bx
                    
                    mov word ptr es:[9*4],offset keyPress
                    mov word ptr es:[9*4+2],cs

                    pop es
                    pop bx
                    ret
        ; setInt9 END ---------------------------------------

        ; keyPress BEGIN ---------------------------------
        ; 名称: keyPress
        ; 参数: 无
        ; 功能: 用户按下键盘后, 调用 int 9 中断例程, 将输入放入缓冲区,
        ;       然后调用 int 16h 从缓冲区中取出按键的通码,
        ;       如果按键方向不与当前蛇的方向相反, 则改变 al 的值
        keyPress:       push bx
                        push ax

                        mov bh,al
                        mov bl,bh

                        in al,60h

                        pushf
                        call dword ptr int9[0]

                        call clearBuffer

                        and bh,10000000b
                        cmp bh,10000000b
                        je keyPressret

                        ; push dx
                        ; mov dx,round
                        ; call debug
                        ; pop dx

                        mov bh,bl
                        or bl,10000000b

                        and bh,00000110b
                        shr bh,1            ; bh 保存当前方向

                        cmp al,11h
                        je processW
                        cmp al,1fh
                        je processS
                        cmp al,1eh
                        je processA
                        cmp al,20h
                        je processD
                        jmp keyPressret

        processW:       cmp bh,2
                        je keyPressret
                        and bl,11111001b
                        jmp keyPressret

        processS:       cmp bh,0
                        je keyPressret
                        and bl,11111001b
                        or bl,00000100b
                        jmp keyPressret

        processA:       cmp bh,1
                        je keyPressret
                        and bl,11111001b
                        or bl,00000110b
                        jmp keyPressret

        processD:       cmp bh,3
                        je keyPressret
                        and bl,11111001b
                        or bl,00000010b
                        jmp keyPressret

                        
                        

        keyPressret:    call clearBuffer
                        cli
                        
                        pop ax
                        mov al,bl
                        pop bx
                        iret

        keyPressend:    nop
        ; keyPress END -----------------------------------



        crash:  push dx
                push ax

                mov dx,0ff00h
                mov ax,0
        crashs: sub ax,1
                sbb dx,0
                cmp ax,0
                jne crashs
                cmp dx,0
                jne crashs

                pop ax
                pop dx
                ret

code ends

end start