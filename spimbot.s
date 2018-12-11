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

RIGHT_WALL_SENSOR 		= 0xffff0054
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
#REQUEST_PUZZLE returns an int array of length 128
puzzle: .space 512
puzzle_solved: .space 512
solution: .space 4
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
    li $t4, TIMER_INT_MASK        #timer interrupt mask
    or $t4, $t4, BONK_INT_MASK  #bon interrupt mmask
    or $t4, $t4, REQUEST_PUZZLE_INT_MASK    #puzzle interrsupt mask
    or $t4, $t4, 1
    mtc0 $t4, $12
  # interrupt setup end
##############################################
# Treasure map set up
  la $t0, treasure_struct # load pointer to treasure map
  sw $t0, TREASURE_MAP($0) # store pointer to treasure map
##############################################
  # initial velocity set up
    li $t0, 0               # velocity = 0
    sw $t0, VELOCITY($0)  # store VELOCITY
##############################################
  #iterate through to solve puzzles
  li $t9, 0
puzzle_solve_loop:
  beq $t9, 1, puzzles_done

  la $t0, puzzle  # temporarily store address of the puzzle
  sw $t0, REQUEST_PUZZLE($0)  # put the address of the puzzle in puzzle request

  li $t8, 0 #puzzle wait loop
  puzzle_not_ready:
  beq $t8, 1, puzzle_ready
  j puzzle_not_ready
  puzzle_ready:

  # Solve Puzzle
  sub $sp, $sp, 36
  sw $ra, 0($sp) # save the return
  sw $t1, 4($sp)
  sw $v0, 8($sp)
  sw $a0, 12($sp)
  sw $a1, 16($sp)
  sw $a2, 20($sp)
  sw $t0, 24($sp)
  sw $t8, 28($sp)
  sw $t9, 32($sp)

  #loop until not changed
  la $a0, puzzle # tree
changed:

  beq $v0, 0, notchanged

  jal rule1

  j changed
notchanged:

  sw $a0, solution($0)

  lw $ra, 0($sp)
  lw $t1, 4($sp)
  lw $v0, 8($sp)
  lw $a0, 12($sp)
  lw $a1, 16($sp)
  lw $a2, 20($sp)
  lw $t0, 24($sp)
  lw $t8, 28($sp)
  lw $t9, 32($sp)
  add $sp, $sp, 36 # restores


  lw $t7, solution($0)
  sw $t7, SUBMIT_SOLUTION($0)

  add $t9, $t9, 1
  j puzzle_solve_loop

puzzles_done:
# #################################################
#   #Begin movment
  infinite_loop:

##########################33
#Turn right algorithm
  li $a0, 10  # velocity is 10
  sw $a0, VELOCITY($zero)
  # interrupt handler ends
  lw $t0, RIGHT_WALL_SENSOR($0)  #RIGHT_WALL_SENSOR
  beq $t8, 0, end_turn # previous wall was closed
  beq $t0, 1, end_turn #branch if wall to right

  li $t1, 90 # 90 degrees to the right
  sw $t1, ANGLE($0)  # schedule turn
  li $t2, 0 # relative
  sw $t2, ANGLE_CONTROL($0)  # turn begin

  end_turn:
  move $t8, $t0
################################

  la $t2, treasure_struct
  #Treasure location check
  lw $t0, 0($t2)# get length
  # set up treasure[0]
  add $t2, $t2, 4 # skip over unsigned
  #loop over length
  li $t1, 0     # i=0
  treasure_loop:
  beq $t1, $t0, treasures_checked

  lhu $t3, 0($t2) # get i-pos
  mul $t3, $t3, 10 # x pos

  add $t2, $t2, 2

  lhu $t4, 0($t2) # get j-pos
  mul $t4, $t4, 10 # y pos

  lw $t5, BOT_X($0) # bot x pos
  lw $t6, BOT_Y($0) # bot y pos

  sub $t5, $t5, $t3 # x - xbot == 0?
  sub $t6, $t6, $t4 # y - ybot == 0?

  add $t2, $t2, 6 # skip over int for now
  add $t1, $t1, 1    # i++

  bne $t5, 0, cond_fail         # condition checks for treasure location
  bne $t6, 0, cond_fail

  sw $t0, PICK_TREASURE($0) # pick up treasure
  li $t1, 0 # velocity = 0
  sw $t1, VELOCITY($0)
  inf_test:
  j inf_test

  cond_fail:            # not in position of treasure
  j treasure_loop

  treasures_checked:

 ###########################

  j infinite_loop
    jr      $ra                         #ret
############################################################
#Movemnt function defintions
    go_north:
              lw $t3, BOT_Y($0)
              sub $t4, $t3, 10

                li $t0, 270
                sw $t0, ANGLE($0)
                li $t1, 1
                sw $t1, ANGLE_CONTROL($0)
                li $t0, 1               # velocity = 0
                sw $t0, VELOCITY($0)

                pos1:
                lw $t3, BOT_Y($0)
                beq $t4, $t3, pos1done
                j pos1
                pos1done:
                li $t0, 0               # velocity = 0
                sw $t0, VELOCITY($0)

                jr $ra

    go_east:
              lw $t3, BOT_X($0)
              add $t4, $t3, 10

                li $t0, 0
                sw $t0, ANGLE($0)
                li $t1, 1
                sw $t1, ANGLE_CONTROL($0)
                li $t0, 1               # velocity = 0
                sw $t0, VELOCITY($0)

                pos2:
                lw $t3, BOT_X($0)
                beq $t4, $t3, pos2done
                j pos2
                pos2done:
                li $t0, 0               # velocity = 0
                sw $t0, VELOCITY($0)

                jr $ra
    go_south:
              lw $t3, BOT_Y($0)
              add $t4, $t3, 10

                li $t0, 90
                sw $t0, ANGLE($0)
                li $t1, 1
                sw $t1, ANGLE_CONTROL($0)
                li $t0, 1               # velocity = 0
                sw $t0, VELOCITY($0)

                pos3:
                lw $t3, BOT_Y($0)
                beq $t4, $t3, pos3done
                j pos3
                pos3done:
                li $t0, 0               # velocity = 0
                sw $t0, VELOCITY($0)

                jr $ra
    go_west:

              lw $t3, BOT_X($0)
              sub $t4, $t3, 10

                li $t0, 180
                sw $t0, ANGLE($0) # angle set
                li $t1, 1
                sw $t1, ANGLE_CONTROL($0) # angle push
                li $t0, 1               # velocity = 0
                sw $t0, VELOCITY($0)

                pos4:
                lw $t3, BOT_X($0)
                beq $t4, $t3, pos4done
                j pos4
                pos4done:
                li $t0, 0               # velocity = 0
                sw $t0, VELOCITY($0)


                jr $ra

###################################################################
#RULE 1
.globl rule1
rule1:
	li  $v0, 0			# bool changed = false

	li  $t0, 0			# i = 0
	li  $t2, 16			# GRID_SQUARED = 16, i,j,k max


loop_one_start:
	beq $t0, $t2, loop_one_end	# i == 16

	li $t1, 0			#j = 0
loop_two_start:
	beq $t1, $t2, loop_two_end	# j == 16

	mul $t3, $t0, 16		# i * N
	add $t3, $t3, $t1		# (i * N) + j
	mul $t3, $t3, 2			# ((i * N) + j) * 2
	add $t3, $t3, $a0		# full address

	lhu $t3, 0($t3) 		# value = board[i][j]

	sub $sp, $sp 24
	sw $ra, 0($sp)
	sw $a0, 4($sp)
	sw $a1, 8($sp)			# STORES
	sw $v0, 12($sp)

	move $a0, $t3			# set value as argument
	jal has_single_bit_set	# call has_single_bit
	move $t7, $v0			# has single bit value return

	lw $ra, 0($sp)
	lw $a0, 4($sp)
	lw $a1, 8($sp)			# LOADS
	lw $v0, 12($sp)
	add $sp, $sp, 24

	beq $t7, $0, condition_single_bit	#first conditional (single_bit_return == 0):jump


	li $t4, 0			# k = 0
loop_three_start:
	beq $t4, $t2, loop_three_end	# k == 16


	beq $t4, $t1, condition_k_not_j # k != j

	mul $t5, $t0, 16		# i * N		temporarily use t5 as board[i][k] address
	add $t5, $t5, $t4		# (i * N) + k
	mul $t5, $t5, 2			# ((i * N) + k) * 2
	add $t5, $t5, $a0		# full address
	lhu $t8, 0($t5)			# load in board		temporarily use t8 as board[i][k]

	and $t6, $t8, $t3		# board[i][k] & value	temporarily use t6 as board[i][k] & value
	beq $t6, $0, condition_k_not_j

	not $t6, $t3			# store ~value
	and $t6, $t6, $t8		# board[i][k] & ~value

	sh $t6, 0($t5)			# store into the board

	li $v0, 1			# change = true

condition_k_not_j:

	beq $t4, $t0, condition_k_not_i	# k != i

	mul $t5, $t4, 16		# k * N		temporarily use t5 as board[k][j] address
	add $t5, $t5, $t1		# (k * N) + j
	mul $t5, $t5, 2			# ((k * N) + j) * 2
	add $t5, $t5, $a0		# full address
	lhu $t8, 0($t5)			# load in board		temporarily use t8 as board[k][j]

	and $t6, $t8, $t3		# board[k][j] & value
	beq $t6, $0, condition_k_not_i

	not $t6, $t3			# store ~value
	and $t6, $t6, $t8		# board[i][k] & ~value

	sh $t6, 0($t5)			# store into the board

	li $v0, 1				# change = true

condition_k_not_i:

	add $t4, $t4, 1				# k ++
	j   loop_three_start		# k loop
loop_three_end:

	sub $sp, $sp, 12			# ii begin
	sw $ra, 0($sp)
	sw $a0, 4($sp)
	sw $v0, 8($sp)

	move $a0, $t0
	jal get_square_begin			# ii = get_square_begin
	move $t8, $v0

	lw $ra, 0($sp)
	lw $a0, 4($sp)
	lw $v0, 8($sp)
	add $sp, $sp, 12		# ii end

	sub $sp, $sp 12			# jj begin
	sw $ra, 0($sp)
	sw $a0, 4($sp)
	sw $v0, 8($sp)

	move $a0, $t1
	jal get_square_begin			# jj = get_square_begin
	move $t9, $v0

	lw $ra, 0($sp)
	lw $a0, 4($sp)
	lw $v0, 8($sp)
	add $sp, $sp, 12		# jj end

	sub $sp, $sp, 8
	sw $s0, 0($sp)
	sw $s1, 4($sp)

	move $s0, $t8
	move $s1, $t9


	move $t5, $s0			# k = ii
	add $s0, $s0, 4		# iimax = ii + 4

loop_four_start:
	beq $t5, $s0, loop_four_end

	move $t6, $s1			# l = jj
	add $t9, $s1, 4		# jjmax = jj + 4

loop_five_start:
	beq $t6, $t9, loop_five_end


							#t4, t7, t8 free to use
	sub $t7, $t5, $t0			# store k - i
	bne $t7, $0, k_ij_condition_fail	# conditional cannot be true if k - i != 0

	sub $t8, $t6, $t1			# store l - j
	bne $t8, $0, k_ij_condition_fail	# conditional cannot be true if l - j != 0

	j continue_skip				# if conditional is true we skip

k_ij_condition_fail:

	mul $t4, $t5, 16		# k * N		temporarily use t4 as board[k][l] address
	add $t4, $t4, $t6		# (k * N) + l
	mul $t4, $t4, 2			# ((k * N) + l) * 2
	add $t4, $t4, $a0		# full address
	lhu $t7, 0($t4)			# load in board		temporarily use t7 as board[k][l]

	and $t8, $t7, $t3		# board[k][l] & value
	beq $t8, $0, continue_skip	# condition fails if  board & value are equal to zero

	not $t8, $t3			# flip value and store in t8
	and $t8, $t7, $t8		# board & ~value

	sh $t8, 0($t4)

	li $v0, 1			#changes = true

continue_skip:

	add $t6, $t6, 1
	j loop_five_start
loop_five_end:

	add $t5, $t5, 1
	j loop_four_start
loop_four_end:

	lw $s0, 0($sp)
	lw $s1, 4($sp)
	add $sp, $sp, 8

condition_single_bit:

	add $t1, $t1, 1			# j ++
	j   loop_two_start		# j loop
loop_two_end:

	add $t0, $t0, 1			# i++
	j   loop_one_start		# i loop
loop_one_end:

	jr	$ra


############## LAB 8 HELPERS
.globl get_square_begin
get_square_begin:
	# round down to the nearest multiple of 4
	div	$v0, $a0, 4
	mul	$v0, $v0, 4
	jr	$ra


# UNTIL THE SOLUTIONS ARE RELEASED, YOU SHOULD COPY OVER YOUR VERSION FROM LAB 7
# (feel free to copy over the solution afterwards)
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
	 sw $a1, REQUEST_PUZZLE_ACK($zero)
   li $t8, 1

	j	interrupt_dispatch

timer_interrupt:
    sw $a1, TIMER_ACK($zero)

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
