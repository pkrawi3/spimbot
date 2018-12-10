.data
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

TIMER                   = 0xffff001c

RIGHT_WALL_SENSOR 	= 0xffff0054
PICK_TREASURE           = 0xffff00e0
TREASURE_MAP            = 0xffff0058

REQUEST_PUZZLE          = 0xffff00d0
SUBMIT_SOLUTION         = 0xffff00d4

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800
REQUEST_PUZZLE_ACK      = 0xffff00d8
# struct spim_treasure
#{
#    short x;
#    short y;
#    int points;
#};
#
#struct spim_treasure_map
#{
#    unsigned length;
#    struct spim_treasure treasures[50];
#};
#

.data
PRINT_INT_ADDR = 0xffff0080
#REQUEST_PUZZLE returns an int array of length 128
puzzle: .space 512
solution: .word 1
treasure_struct: .space 404

.align 4
ddfs:      .word 128

#
#Put any other static memory you need here
#

.text
main:

##############################################

  # interrupt set up begin
    li $t4, TIMER_INT_MASK				#timer interrupt mask
    or $t4, $t4, BONK_INT_MASK  			#bon interrupt mmask
    or $t4, $t4, REQUEST_PUZZLE_INT_MASK    		#puzzle interrupt mask
    or $t4, $t4, 1
    mtc0 $t4, $12

##############################################

# Treasure map set up begin
  la $t0, treasure_struct 				# load pointer to treasure map
  sw $t0, TREASURE_MAP($0) 				# store pointer to treasure map

##############################################

  # initial velocity set up
    li $t0, 0               				# velocity = 0
    sw $t0, VELOCITY($0)  				# store VELOCITY

##############################################



  #Begin movment using turn right algorithm

	li	$s0, 0
	li	$s1, 0
	li	$s2, 0
	li	$s3, 1
	li	$s4, 0
	li	$s5, 1
	li	$s6, 0

infinite_loop:

	beq	$s5, 1, request_puzzle			#s5 = 1 means timer interrupt has been received and its time to solve a puzzle
	beq	$s6, 1, move_				#s6 = 1 means timer interrupt has been set
	lw	$s7, TIMER
	add	$s7, $s7, 60000				#change this number to decrease or increase time between puzzle solves
	sw	$s7, TIMER
	li	$s6, 1
	j	move_

request_puzzle:
	bne	$s0, 0, solve_puzzle			#s0 == 1 means request has been sent
	la	$t7, puzzle
	beq	$s1, 1, solve_puzzle			#s1 == 1 means puzzle is ready
	sw	$t7, REQUEST_PUZZLE
	li	$s0, 1

solve_puzzle:
	bne	$s1, 1, move_
	li 	$t0, 0  # velocity is 10
	sw 	$t0, VELOCITY($zero)
	add	$s2, $s2, 1
	la	$t7, puzzle
	move	$a0, $t7
	jal 	rule1
	beq	$s2, 3, submit
	j	solve_puzzle

submit:
	la	$t7, puzzle
	sw	$t7, SUBMIT_SOLUTION
	li	$s1, 0
	li	$s2, 0
	li	$s5, 0

move_:
	li 	$t0, 10  # velocity is 10
	sw 	$t0, VELOCITY($zero)

	lw 	$s4, RIGHT_WALL_SENSOR($zero)  #RIGHT_WALL_SENSOR
	move    $v0, $s4
	sw 	$s4, PRINT_INT_ADDR
	beq 	$s4, 1, end_turn 	#branch if wall to right
	beq 	$s3, 0, end_turn 	#previous wall was open

	li 	$s5, 90 # 90 degrees to the right
	sw 	$s5, ANGLE($0)  	# schedule turn
	li 	$s6, 0 # relative
	sw 	$s6, ANGLE_CONTROL($0)  # turn begin

	end_turn:
	move $s3, $s4

	j infinite_loop
	jr      $ra                         #ret

###################################################################


###################################################################
board_address:
	mul	$v0, $a1, 16		# i*16
	add	$v0, $v0, $a2		# (i*16)+j
	sll	$v0, $v0, 1		# ((i*9)+j)*2
	add	$v0, $a0, $v0
	jr	$ra

.globl rule1
rule1:
	sub	$sp, $sp, 32
	sw	$ra, 0($sp)		# save $ra and free up 7 $s registers for
	sw	$s0, 4($sp)		# i
	sw	$s1, 8($sp)		# j
	sw	$s2, 12($sp)		# board
	sw	$s3, 16($sp)		# value
	sw	$s4, 20($sp)		# k
	sw	$s5, 24($sp)		# changed
	sw	$s6, 28($sp)		# temp
	move	$s2, $a0		# store the board base address
	li	$s5, 0			# changed = false

	li	$s0, 0			# i = 0
r1_loop1:
	li	$s1, 0			# j = 0
r1_loop2:
	move	$a0, $s2		# board
	move 	$a1, $s0		# i
	move	$a2, $s1		# j
	jal	board_address
	lhu	$s3, 0($v0)		# value = board[i][j]
	move	$a0, $s3
	jal	has_single_bit_set
	beq	$v0, 0, r1_loop2_bot	# if not a singleton, we can go onto the next iteration

	li	$s4, 0			# k = 0
r1_loop3:
	beq	$s4, $s1, r1_skip_row	# skip if (k == j)
	move	$a0, $s2		# board
	move 	$a1, $s0		# i
	move	$a2, $s4		# k
	jal	board_address
	lhu	$t0, 0($v0)		# board[i][k]
	and	$t1, $t0, $s3
	beq	$t1, 0, r1_skip_row
	not	$t1, $s3
	and	$t1, $t0, $t1
	sh	$t1, 0($v0)		# board[i][k] = board[i][k] & ~value
	li	$s5, 1			# changed = true

r1_skip_row:
	beq	$s4, $s0, r1_skip_col	# skip if (k == i)
	move	$a0, $s2		# board
	move 	$a1, $s4		# k
	move	$a2, $s1		# j
	jal	board_address
	lhu	$t0, 0($v0)		# board[k][j]
	and	$t1, $t0, $s3
	beq	$t1, 0, r1_skip_col
	not	$t1, $s3
	and	$t1, $t0, $t1
	sh	$t1, 0($v0)		# board[k][j] = board[k][j] & ~value
	li	$s5, 1			# changed = true

r1_skip_col:
	add	$s4, $s4, 1		# k ++
	blt	$s4, 16, r1_loop3

	## doubly nested loop
	move	$a0, $s0		# i
	jal	get_square_begin
	move	$s6, $v0		# ii
	move	$a0, $s1		# j
	jal	get_square_begin	# jj

	move 	$t0, $s6		# k = ii
	add	$t1, $t0, 4		# ii + GRIDSIZE
	add 	$s6, $v0, 4		# jj + GRIDSIZE

r1_loop4_outer:
	sub	$t2, $s6, 4		# l = jj  (= jj + GRIDSIZE - GRIDSIZE)

r1_loop4_inner:
	bne	$t0, $s0, r1_loop4_1
	beq	$t2, $s1, r1_loop4_bot

r1_loop4_1:
	mul	$v0, $t0, 16		# k*16
	add	$v0, $v0, $t2		# (k*16)+l
	sll	$v0, $v0, 1		# ((k*16)+l)*2
	add	$v0, $s2, $v0		# &board[k][l]
	lhu	$v1, 0($v0)		# board[k][l]
   	and	$t3, $v1, $s3		# board[k][l] & value
	beq	$t3, 0, r1_loop4_bot

	not	$t3, $s3
	and	$v1, $v1, $t3
	sh	$v1, 0($v0)		# board[k][l] = board[k][l] & ~value
	li	$s5, 1			# changed = true

r1_loop4_bot:
	add	$t2, $t2, 1		# l++
	blt	$t2, $s6, r1_loop4_inner

	add	$t0, $t0, 1		# k++
	blt	$t0, $t1, r1_loop4_outer


r1_loop2_bot:
	add	$s1, $s1, 1		# j ++
	blt	$s1, 16, r1_loop2

	add	$s0, $s0, 1		# i ++
	blt	$s0, 16, r1_loop1

	move	$v0, $s5		# return changed
	lw	$ra, 0($sp)		# restore registers and return
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	add	$sp, $sp, 32
	jr	$ra

.globl get_square_begin
get_square_begin:
	div	$v0, $a0, 4
	mul	$v0, $v0, 4
	jr	$ra


.globl has_single_bit_set
has_single_bit_set:
	beq	$a0, 0, hsbs_ret_zero	# return 0 if value == 0
	sub	$a1, $a0, 1
	and	$a1, $a0, $a1
	bne	$a1, 0, hsbs_ret_zero	# return 0 if (value & (value - 1)) == 0
	li	$v0, 1
	jr	$ra
hsbs_ret_zero:
	li	$v0, 0
	jr	$ra


get_lowest_set_bit:
	li	$v0, 0			# i
	li	$t1, 1

glsb_loop:
	sll	$t2, $t1, $v0		# (1 << i)
	and	$t2, $t2, $a0		# (value & (1 << i))
	bne	$t2, $0, glsb_done
	add	$v0, $v0, 1
	blt	$v0, 16, glsb_loop	# repeat if (i < 16)

	li	$v0, 0			# return 0
glsb_done:
	jr	$ra


.globl print_board
print_board:
	sub	$sp, $sp, 20
	sw	$ra, 0($sp)		# save $ra and free up 4 $s registers for
	sw	$s0, 4($sp)		# i
	sw	$s1, 8($sp)		# j
	sw	$s2, 12($sp)		# the function argument
	sw	$s3, 16($sp)		# the computed pointer (which is used for 2 calls)
	move	$s2, $a0

	li	$s0, 0			# i
pb_loop1:
	li	$s1, 0			# j
pb_loop2:
	mul	$t0, $s0, 16		# i*16
	add	$t0, $t0, $s1		# (i*16)+j
	sll	$t0, $t0, 1		# ((i*16)+j)*2
	add	$s3, $s2, $t0
	lhu	$a0, 0($s3)
	jal	has_single_bit_set
	beq	$v0, 0, pb_star		# if it has more than one bit set, jump
	lhu	$a0, 0($s3)
	jal	get_lowest_set_bit	#
	add	$v0, $v0, 1		# $v0 = num
	la	$t0, symbollist
	add	$a0, $v0, $t0		# &symbollist[num]
	lb	$a0, 0($a0)		#  symbollist[num]
	li	$v0, 11
	syscall
	j	pb_cont

pb_star:
	li	$v0, 11			# print a "*"
	li	$a0, '*'
	syscall

pb_cont:
	add	$s1, $s1, 1		# j++
	blt	$s1, 16, pb_loop2

	li	$v0, 11			# at the end of a line, print a newline char.
	li	$a0, '\n'
	syscall

	add	$s0, $s0, 1		# i++
	blt	$s0, 16, pb_loop1

	lw	$ra, 0($sp)		# restore registers and return
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	add	$sp, $sp, 20
	jr	$ra

########################################################################
.kdata
chunkIH:    .space 28
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
        move      $k1, $at        # Save $at
.set at
        la        $k0, chunkIH
        sw        $a0, 0($k0)        # Get some free registers
        sw        $v0, 4($k0)        # by storing them to a global variable
        sw        $t0, 8($k0)
        sw        $t1, 12($k0)
        sw        $t2, 16($k0)
        sw        $t3, 20($k0)

        mfc0      $k0, $13             # Get Cause register
        srl       $a0, $k0, 2
        and       $a0, $a0, 0xf        # ExcCode field
        bne       $a0, 0, non_intrpt



interrupt_dispatch:            # Interrupt:
    mfc0       $k0, $13        # Get Cause register, again
    beq        $k0, 0, done        # handled all outstanding interrupts

    and        $a0, $k0, BONK_INT_MASK    # is there a bonk interrupt?
    bne        $a0, 0, bonk_interrupt

    and        $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne        $a0, 0, timer_interrupt

	and 	$a0, $k0, REQUEST_PUZZLE_INT_MASK
	bne 	$a0, 0, request_puzzle_interrupt

    li        $v0, PRINT_STRING    # Unhandled interrupt types
    la        $a0, unhandled_str
    syscall
    j    done

bonk_interrupt:
    sw $a1, BONK_ACK($zero)

    li $t1, 180  # 180 degree turn
    sw $t1, ANGLE($0) # schedule the turn
    li $t2, 0 # relative
    sw $t2, ANGLE_CONTROL($0) # beign the turn

    j interrupt_dispatch    # see if other interrupts are waiting

request_puzzle_interrupt:
	 li	$s0, 0
	 li	$s1, 1
	 sw	$t0, REQUEST_PUZZLE_ACK
	 j	interrupt_dispatch

timer_interrupt:
    	sw 	$a1, TIMER_ACK($zero)
	li	$s5, 1
	li	$s6, 0
    	j        interrupt_dispatch    # see if other interrupts are waiting

non_intrpt:                # was some non-interrupt
    li        $v0, PRINT_STRING
    la        $a0, non_intrpt_str
    syscall                # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH
    lw      $a0, 0($k0)        # Restore saved registers
    lw      $v0, 4($k0)
	lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
.set noat
    move    $at, $k1        # Restore $at
.set at
    eret
