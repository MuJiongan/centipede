.data
    centipedeLocation: .space 40 
    centipedeDirection: .space 40
    displayAddress: .word 0x10008000
    headColour: .word 0xff0000 # red
    bodyColour: .word 0x0000ff # blue
    bugBlasterColour: .word 0x800080 # purple
    mushroomColour: .word 0xFFC0CB # pink
    maximumMushroomNumber: .word 5
    mushroomArray: .space 3968
    fleaLocation: .space 4
    fleaColour: .word 0xFFFF00
    dartLocation: .space 4
    dartColour: .word 0xFFFFFF
    
.text
    # s3 always stores the bug blaster's location, s5 stores centipede life
    lw $t0, displayAddress # $t0 stores the base address for display
    initializeBugBlasterLocation:
        addi $s3, $t0, 4032
        j initializeMushrooms
    initializeMushrooms:
        lw $t1, maximumMushroomNumber # t1 stores the current number of mushrooms
        
        setOneMushroom:
            beq $t1, 0, initializeCentipedeLocation
            jal get_random_number
            addi $a0, $a0, 32
            sll $a0, $a0, 2  # random number * 4
            addi $t2, $zero, 1  # store 1 into each element if a mushroom exists
            sw $t2, mushroomArray($a0)
            addi $t1, $t1, -1
            j setOneMushroom






    initializeCentipedeLocation:
        addi $t1, $zero, 0  # loop variable storing the index
        while:
            beq $t1, 40, initializeCentipedeDirection 
            
            # draw tails
            add $s0, $t0, $t1  #s0 stores the location
            sw $s0, centipedeLocation($t1)
            addi $t1, $t1, 4
            j while
    
    initializeCentipedeDirection:
    	addi $t1, $zero, 0  # loop variable storing the index
        initializeDirection:
            beq $t1, 40, initializeFlea
            
          
            addi $s0, $zero, 4  # all centipede parts by default are moving to the right
            sw $s0, centipedeDirection($t1)
            addi $t1, $t1, 4
            j initializeDirection

    
    
    initializeFlea:
        addi $t1, $zero, -1
        addi $t2, $zero, 0
        sw $t1, fleaLocation($t2)
        j initializeDartLocation
    
    initializeDartLocation:
        addi $t1, $zero, -1
        sw $t1, dartLocation($zero)
        j initializeLife
    initializeLife:
        addi $s5, $zero, 2
        j drawCentipede
    # ==========Loop starts here================
    
    
    repaint:
        addi $t1, $zero, 0  # loop variable storing the index
        repaintSquare: 
            beq $t1, 4096, keyboard
            li $s1, 0x000000 # load black
            add $t2, $t0, $t1
            sw $s1, 0($t2) # paint the square black
            addi $t1, $t1, 4 
            j repaintSquare
            
    
    keyboard:
        # Interact with keyboard
        lw $t8, 0xffff0000				# Check MMIO location for keypress 
        beq $t8, 1, keyboard_input		# If we have input, jump to handler
        j keyboard_input_done			# Otherwise, jump till end

        keyboard_input:
            lw $t8, 0xffff0004				# Read Key value into t8
            beq $t8, 0x6A, keyboard_left	# If `j`, move left
            beq $t8, 0x6B, keyboard_right	# If `k`, move right
            beq $t8, 0x78, keyboard_shoot   # if 'x', shoot dart


            j keyboard_input_done		# Otherwise, ignore...

            keyboard_left:
                addi $s4, $t0, 3968
                beq $s3, $s4, transfer_left	# If at left wall, warp to right
                addi $s3, $s3, -4				# Otherwise, decrement x
                j keyboard_input_done			# done

                transfer_left:	
                    addi $s3, $t0, 4092			# doodle.x = screenWdith-1
                    j keyboard_input_done		# done

            keyboard_right:
                addi $s4, $t0, 4092
                beq $s3, $s4, transfer_right
                addi $s3, $s3, 4
                j keyboard_input_done

                transfer_right:
                    addi $s3, $t0, 3968
                    j keyboard_input_done
            keyboard_shoot:
                lw $t1, dartLocation($zero)
                bne $t1, -1, keyboard_input_done
                addi $t1, $s3, -128
                sw $t1, dartLocation($zero)
                j keyboard_input_done


        keyboard_restart:
        j keyboard

        keyboard_input_done:
            # do nothing

    # updating the next direction
    updateCentipedeDirection:
        addi $t1, $zero, 0
        updateOneDirection:
            beq $t1, 40, updateCentipedeLocation
            lw $a0, centipedeLocation($t1)
            lw $s0, centipedeDirection($t1)
            # moving left and hit a wall or mushroom
            beq $s0, -4, checkLeft
            beq $s0, 4, checkRight
            beq $s0, 128, checkDown 
            j increment
                checkLeft:
                    jal if_hit_wall
                    beq $v0, 1, go_down
                    addi $a0, $a0, -4
                    jal if_hit_mushroom
                    beq $v0, 1, go_down
                    j increment
                checkRight:
                    addi $a0, $a0, 4
                    jal if_hit_wall
                    beq $v0, 1, go_down
                    jal if_hit_mushroom
                    beq $v0, 1, go_down
                    j increment

                checkDown:
                    sub $t4, $a0, $t0
                    addi $t5, $zero, 128
                    div $a0, $t5
                    mflo $t4
                    addi $t5, $zero, 2
                    div $t4, $t5
                    mfhi $t4
                    beq $t4, 0, handle_even
                    beq $t4, 1, handle_odd
                    # if t4 is even, moving right or movedown
                    handle_even:
                        addi $a0, $a0, 4
                        jal if_hit_wall
                        beq $v0, 1, go_down
                        jal if_hit_mushroom
                        beq $v0, 1, go_down
                        j go_right
                    # if t4 is odd, moving left or movedown
                    handle_odd:
                        jal if_hit_wall
                        beq $v0, 1, go_down
                        addi $a0, $a0, -4
                        jal if_hit_mushroom
                        beq $v0, 1, go_down
                        j go_left
                    


                go_down: 
                    addi $s0, $zero, 128
                    sw $s0, centipedeDirection($t1)
                    j increment
                go_right:
                    addi $s0, $zero, 4
                    sw $s0, centipedeDirection($t1)
                    j increment
                go_left:
                    addi $s0, $zero, -4
                    sw $s0, centipedeDirection($t1)
                    j increment
                increment:
                    addi $t1, $t1, 4
                    j updateOneDirection

                







    updateCentipedeLocation:
    	addi $t1, $zero, 0  # loop variable storing the index
        updateLocation:
            beq $t1, 40, updateDartLocation 
            
            lw $s0, centipedeLocation($t1)    #load location
            lw $s1, centipedeDirection($t1)   #load direction
            add $s2, $s0, $s1
            sw $s2, centipedeLocation($t1) 
            addi $t1, $t1, 4
            j updateLocation
    
    updateDartLocation:
        lw $t1, dartLocation($zero)
        beq $t1, -1, updateFleaLocation
        addi $t1, $t1, -128
        blt $t1, $t0, resetDartLocation
        sw $t1, dartLocation($zero)
        j updateFleaLocation
            resetDartLocation:
                addi $t2, $zero, -1
                sw $t2, dartLocation($zero)
                j updateFleaLocation
    
    updateFleaLocation:
        
        lw $t1, fleaLocation($zero)
        beq $t1, -1, potentiallyGenerateFlea
        bne $t1, -1, moveFlea
        potentiallyGenerateFlea:
            jal generate_random_flea_number
            beq $a0, 0, generateFlea
            j checkGameOver
            generateFlea:
            jal generate_random_flea_number
            sll $a0, $a0, 2
            sw $a0, fleaLocation($zero)
            j checkGameOver
        moveFlea:
            lw $t1, fleaLocation($zero)
            bge $t1, 4092, resetFleaLocation
            addi $t1, $t1, 128
            sw $t1, fleaLocation($zero)
            j checkGameOver
            resetFleaLocation:
                addi $t2, $zero, -1
                sw $t2, fleaLocation($zero)
                j checkGameOver



    
    checkGameOver:
        # centipede hits the bug blaster
        addi $t1, $zero, 0  # loop variable storing the index
        checkCentipede:
            beq $t1, 40, checkFlea
            lw $s0, centipedeLocation($t1)
            beq $s0, $s3, game_over
            addi $t1, $t1, 4
            j checkCentipede
    
        checkFlea:
            lw $t5, fleaLocation($zero)
            add $t5, $t5, $t0
            beq $s3, $t5, game_over
         

    checkDartHitMushroom:
        lw $t1, dartLocation($zero)
        beq $t1, -1, checkDartHitCentipede
        sub $t1, $t1, $t0
        lw $t2, mushroomArray($t1)
        beq $t2, 0, checkDartHitCentipede
        sw $zero, mushroomArray($t1)
        addi $t1, $zero, -1
        sw $t1, dartLocation($zero)
    
    checkDartHitCentipede:
        lw $t1, dartLocation($zero)
        beq $t1, -1, drawCentipede
        addi $t2, $zero, 0 # loop variable
        checkDartOneCentipede:
        beq $t2, 40, drawCentipede
        lw $t3, centipedeLocation($t2)
        beq $t3, $t1, decreaseLife
        addi $t2, $t2, 4
        j checkDartOneCentipede
        
        decreaseLife:
            addi $t1, $zero, -1
            sw $t1, dartLocation($zero)
            addi $s5, $s5, -1
            beq $s5, -1, initializeMushrooms
            
            j drawCentipede
             # do something if it is less than 0

            
    drawCentipede:
    	addi $t1, $zero, 0  # loop variable storing the index
    	lw $t2 headColour
    	lw $t3 bodyColour
    	drawTail:
            beq $t1, 36, drawHead
            
            # draw tails
            lw $s0, centipedeLocation($t1)
            sw $t3, 0($s0)
            addi $t1, $t1, 4
            j drawTail
            
        drawHead:
            lw $s0, centipedeLocation($t1)
            sw $t2, 0($s0)
            j drawBugBlaster
    
    drawBugBlaster:
        lw $t2, bugBlasterColour
        sw $t2, 0($s3)
        j drawMushroom

    

    drawMushroom:
        addi $t1, $zero, 0  # loop variable storing the index
        drawOneMushroom: 
            beq $t1, 3968, drawFlea
            lw $s1, mushroomColour # load pink
            add $t2, $t0, $t1
            lw $t3, mushroomArray($t1)
            beq $t3, 1, paintMushroom
            addi $t1, $t1, 4
            j drawOneMushroom

        paintMushroom:
            sw $s1, 0($t2) # paint the square pink
            addi $t1, $t1, 4
            j drawOneMushroom

    drawFlea:
        lw $t1, fleaLocation($zero)
        lw $t2, fleaColour
        beq $t1, -1, drawDart
        add $t1, $t0, $t1
        sw $t2, 0($t1)

    drawDart:
        lw $t1, dartLocation($zero)
        lw $t2, dartColour
        beq $t1, -1, sleep
        sw $t2, 0($t1)


    sleep:
        li $v0, 32				# Sleep op code
	li $a0, 50				# Sleep 1/20 second 
	syscall
	j repaint
            


get_random_number:
  	li $v0, 42         # Service 42, random int bounded
  	li $a0, 0          # Select random generator 0
  	li $a1, 924             
  	syscall             # Generate random int (returns in $a0)
  	jr $ra

generate_random_flea_number:
    li $v0, 42         # Service 42, random int bounded
  	li $a0, 0         # Select random generator 0
  	li $a1, 31             
  	syscall             # Generate random int (returns in $a0)
  	jr $ra

square_to_address:
    sll $a0, $a0, 2    # square = square * 4
    add $v0, $t0, $a0 
    jr $ra

if_hit_mushroom:
    sub $t3, $a0, $t0
    lw $v0, mushroomArray($t3)
    jr $ra

if_hit_wall:
    addi $t5, $zero, 128
    div $a0, $t5
    mfhi $t4
    beq $t4, 0, returnOne
    addi $v0, $zero, 0
    jr $ra
    returnOne: 
    addi $v0, $zero, 1
    jr $ra



   


game_over:
    lw $t0, displayAddress
	addi $t0, $t0, 1576
	lw $t1, mushroomColour
	sw $t1, 128($t0)
	sw $t1, 256($t0)
	sw $t1, 384($t0)
	sw $t1, 388($t0)
	sw $t1, 392($t0)
	sw $t1, 520($t0)
	sw $t1, 512($t0)
	sw $t1, 640($t0)
	sw $t1, 644($t0)
	sw $t1, 648($t0)
	#draw y
	sw $t1, 400($t0)
	sw $t1, 528($t0)
	sw $t1, 656($t0)
	sw $t1, 408($t0)
	sw $t1, 536($t0)
	sw $t1, 660($t0)
	sw $t1, 664($t0)
	sw $t1, 792($t0)
	sw $t1, 920($t0)
	sw $t1, 916($t0)
	sw $t1, 912($t0)
	#draw E
	sw $t1, 672($t0)
	sw $t1, 676($t0)
	sw $t1, 680($t0)
	sw $t1, 544($t0)
	sw $t1, 416($t0)
	sw $t1, 420($t0)
	sw $t1, 424($t0)
	sw $t1, 288($t0)
	sw $t1, 160($t0)
	sw $t1, 164($t0)
	sw $t1, 168($t0)
	#draw !
	sw $t1, 176($t0)
	sw $t1, 304($t0)
	sw $t1, 432($t0)
	sw $t1, 688($t0)
    addi $t0, $t0, -1576
    lastKeyboard:
    lw $t8, 0xffff0000				# Check MMIO location for keypress 
    beq $t8, 1, lastKeyboard_input		# If we have input, jump to handler
    j lastKeyboard_done
	lastKeyboard_input:
        lw $t8, 0xffff0004				# Read Key value into t8
        beq $t8, 0x72, initializeBugBlasterLocation
        beq $t8, 0x63, Exit
       
        j lastKeyboard_done
    
    lastKeyboard_done:
        li $v0, 32				# Sleep op code
	    li $a0, 50				# Sleep 1/20 second 
	    syscall
        j lastKeyboard

    RepaintandInitializeBugBlasterLocation:
        addi $t1, $zero, 0  # loop variable storing the index
        repaintSquareEnd: 
            beq $t1, 4096, initializeBugBlasterLocation
            li $s1, 0x000000 # load black
            add $t2, $t0, $t1
            sw $s1, 0($t2) # paint the square black
            addi $t1, $t1, 4 
            j repaintSquareEnd
    Exit:
        li $v0, 10 # terminate the program gracefully
        syscall
