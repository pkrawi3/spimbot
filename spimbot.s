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
  #Begin movment
  #Turn right algorithm
  li	$s0, 0
infinite_loop:
  bne	$s0, 0, check_for_solve			## s0 == 1 means puzzle is being requested
  li	$s0, 1
  la	$t7, puzzle
  sw	$t7, REQUEST_PUZZLE

check_for_solve:
  bne	$s1, 1, move_				## s1 == 1 means puzzle is ready
  la	$t7, puzzle
  move	$a0, $t7
  li	$a1, 1
  li	$a2, 1
  jal	dfs
  sw	$v0, solution
  la	$t7, solution
  sw	$t7, SUBMIT_SOLUTION
  li	$s1, 0

move_:
  li $a0, 10  # velocity is 10
  sw $a0, VELOCITY($zero)
  # interrupt handler ends
  lw $t0, RIGHT_WALL_SENSOR($0)  #RIGHT_WALL_SENSOR
  beq $t5, 0, end_turn # previous wall was closed
  beq $t0, 1, end_turn #branch if wall to right

  li $t1, 90 # 90 degrees to the right
  sw $t1, ANGLE($0)  # schedule turn
  li $t2, 0 # relative
  sw $t2, ANGLE_CONTROL($0)  # turn begin

  end_turn:
  move $t5, $t0

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
#DFS for solutions to puzzle
.globl dfs
dfs:
sub		$sp, $sp, 16		# STACK STORE
sw 		$ra, 0($sp)		# Store ra
sw		$s0, 4($sp)		# s0 = tree
sw		$s1, 8($sp)		# s1 = i
sw		$s2, 12($sp)	# s2 = input
move 	$s0, $a0
move 	$s1, $a1
move	$s2, $a2
##	if (i >= 127) {
##		return -1;
##	}
_dfs_base_case_one:
blt     $s1, 127, _dfs_base_case_two
li      $v0, -1
j _dfs_return
##	if (input == tree[i]) {
##		return 0;
##	}
_dfs_base_case_two:
mul		$t1, $s1, 4
add		$t2, $s0, $t1
lw      $t1, 0($t2)  			# tree[i]

bne     $t1, $s2, _dfs_ret_one
li      $v0, 0
j _dfs_return
##	int ret = DFS(tree, 2 * i, input);
##	if (ret >= 0) {
##		return ret + 1;
##	}
_dfs_ret_one:
mul		$a1, $s1, 2
jal 	dfs				##	int ret = DFS(tree, 2 * i, input);
blt		$v0, 0, _dfs_ret_two	##	if (ret >= 0)
addi	$v0, 1					##	return ret + 1
j _dfs_return
##	ret = DFS(tree, 2 * i + 1, input);
##	if (ret >= 0) {
##		return ret + 1;
##	}
_dfs_ret_two:
mul		$a1, $s1, 2
addi	$a1, 1
jal 	dfs				##	int ret = DFS(tree, 2 * i + 1, input);
blt		$v0, 0, _dfs_return		##	if (ret >= 0)
addi	$v0, 1					##	return ret + 1
j _dfs_return
##	return ret;
_dfs_return:
lw 		$ra, 0($sp)
lw		$s0, 4($sp)
lw		$s1, 8($sp)
lw		$s2, 12($sp)
add		$sp, $sp, 16
jal     $ra
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
