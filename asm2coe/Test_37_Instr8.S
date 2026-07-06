.globl test37
.section .text
test37:
	ori x5, x0, 0x435
	lui x6, 0x1
	or x5,x5,x6
	lui x6, 0x98765
	addi x7, x5, 0x578
	addi x8, x6, -1024
	xori x9, x5, 0x7bc
	sltiu x3, x7, 0x19
	sltiu x4, x5, -1
	andi x18, x9, 0x765
	slti x20, x6, 0x123
	sub x19, x6, x5
	xor x21, x20, x6
	add x22, x21, x20
	add x22, x22, x5
	sub x23, x22, x6
	or  x25, x23, x22
	and x26, x23, x22
	slt x27, x25, x26
	sltu x28, x25, x26
    addi x3, x3, 4
	sll x27, x26, x3
	srl x28, x25, x3
	sra x29, x25, x3
	slli  x27, x19, 24
	srli x28, x19, 4
	srai x29, x19, 4
	addi x3, x0, 0
    addi x5,x0, 0xEF
	sw x19, 0(x3)
	sw x21, 4(x3)
	sw x23, 8(x3)
	sh x26, 4(x3)
	sh x19, 10(x3)
	sb x5, 7(x3)
	sb x5, 9(x3)
	sb x5, 8(x3)
    lw  x5, 0(x3)
	sw x5, 12(x3)
	lh x7, 2(x3)
	sw x7, 16(x3)
	lhu x7, 2(x3)
	sw x7, 20(x3)
	lb x8, 3(x3)
	sw x8, 24(x3)
	lbu x8, 3(x3)
	sw x8, 28(x3)
	lbu x8, 1(x3)
	sw x8, 32(x3)
	sw x0, 0(x3)
	and x9, x0, x9
	bne x5, x7,  _lb1
	addi x9, x9, 2
_lb1:
	bge x5, x7, _lb2
	addi x9, x9, 7
_lb2:
	bgeu x5, x7, _lb3
	addi x9, x9,5
_lb3:
	blt x5, x7, _lb4
	addi x9, x9, 3
_lb4:
	bltu x5, x7, _lb4
	addi x9, x9, 6
_lb5:
	beq x7, x8, _lb6
	addi x9, x9, 1
_lb6:
	sw x9, 0(x3)
	lw x10, 0(x3)
	jal x1, F_Test_JAL
	addi x10, x10, 3
	sw x10, 0(x3)
F_Test_JAL:
	ori x10, x10, 0x7a1
	sw x10, 0(x3)
	jalr x0, x1, 0
