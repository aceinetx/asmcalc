LINK = 1

if LINK
format ELF
else
format ELF executable
end if

if LINK
public _start
public error
public request
public is_numchar
public next
public is_mul_div
public is_plus_minus
public lit
public factor
public term
public expr
public parse

public unknown_token
public syntax
public input
public token
public token_value
public pos

section '.text' executable
else
entry _start
end if

SYS_EXIT  = 1
SYS_READ  = 3
SYS_WRITE = 4
STDOUT    = 1
STDIN     = 2

TOK_NUMBER = 0
TOK_PLUS   = 1
TOK_MINUS  = 2
TOK_MUL    = 3
TOK_DIV    = 4
TOK_LPAREN = 5
TOK_RPAREN = 6
TOK_END    = 7

; edi - message
; esi - size
error:
	mov eax, SYS_WRITE
	mov ebx, STDOUT
	mov ecx, edi
	mov edx, esi
	int 0x80

	mov eax, SYS_EXIT
	mov ebx, 1
	int 0x80

request:
	pusha
	mov eax, SYS_READ
	mov ebx, STDIN
	mov ecx, input
	mov edx, 1024
	int 0x80
	mov dword [pos], input
	popa
	ret




; dl - char
; al - 0/1
is_numchar:
	cmp dl, '0'
	jl .no
	cmp dl, '9'
	jg .no

.yes:
	mov al, 1
	ret
.no:
	mov al, 0
	ret




next:
	pusha

.loop:
	mov eax, [pos]
	mov dl, byte [eax]

	call is_numchar
	test al, al
	jnz .numchar
	cmp dl, '+'
	je .plus
	cmp dl, '-'
	je .minus
	cmp dl, '*'
	je .mul
	cmp dl, '/'
	je .div
	cmp dl, '('
	je .lparen
	cmp dl, ')'
	je .rparen
	cmp dl, 0
	je .end
	cmp dl, 10
	je .end
	cmp dl, ' '
	jne .unknown

	inc dword [pos]
	jmp .loop

.unknown:
	mov edi, unknown_token
	mov esi, unknown_token_size
	call error

.end:
	mov dword [token], TOK_END
	jmp .quit

.numchar:
	mov ecx, 0

	.numchar_loop:
		mov eax, [pos]
		mov dl, byte [eax]

		call is_numchar
		test al, al
		jz .numchar_end

		imul ecx, 10
		add ecx, edx
		sub ecx, 48

		inc dword [pos]
		jmp .numchar_loop
	
	.numchar_end:
	
	mov dword [token], TOK_NUMBER
	mov dword [token_value], ecx
	jmp .quit

.plus:
	inc dword [pos]
	mov dword [token], TOK_PLUS
	jmp .quit
.minus:
	inc dword [pos]
	mov dword [token], TOK_MINUS
	jmp .quit
.mul:
	inc dword [pos]
	mov dword [token], TOK_MUL
	jmp .quit
.div:
	inc dword [pos]
	mov dword [token], TOK_DIV
	jmp .quit
.lparen:
	inc dword [pos]
	mov dword [token], TOK_LPAREN
	jmp .quit
.rparen:
	inc dword [pos]
	mov dword [token], TOK_RPAREN
	jmp .quit

.quit:
	popa
	ret


; dl - token
; al - result (0/1)
is_mul_div:
	cmp al, TOK_MUL
	je .yes
	cmp al, TOK_DIV
	je .yes

.no:
	mov al, 0
	ret
.yes:
	mov al, 1
	ret


; dl - token
; al - result (0/1)
is_plus_minus:
	cmp al, TOK_PLUS
	je .yes
	cmp al, TOK_MINUS
	je .yes

.no:
	mov al, 0
	ret
.yes:
	mov al, 1
	ret


; result - eax
lit:
	push ebp
	mov ebp, esp
	sub esp, 32
	
	mov al, [token]
	cmp al, TOK_NUMBER
	je .number

	mov edi, syntax
	mov esi, syntax_size
	call error

.number:
	mov eax, [token_value]
	call next
	jmp .ret

.ret:
	leave
	ret


; result - eax
factor:
	push ebp
	mov ebp, esp
	sub esp, 32

	mov dword [ebp-4], 0 ; value
	
	mov al, [token]
	cmp al, TOK_LPAREN
	je .lparen

	call lit
	mov dword [ebp-4], eax
	jmp .ret

.lparen:
	call next
	call expr
	mov dword [ebp-4], eax
	call next
	jmp .ret

.ret:
	mov eax, dword [ebp-4]
	leave
	ret

; result - eax
term:
	push ebp
	mov ebp, esp
	sub esp, 32
	
	call factor
	mov [ebp-4], eax ; left

	mov al, [token]
	mov [ebp-5], al ; op

	; int3

	.loop:
		mov dl, [ebp-5]
		call is_mul_div
		test al, al
		jz .end

		call next

		call factor
		mov [ebp-9], eax ; right

		mov dl, [ebp-5]
		cmp dl, TOK_MUL
		je .mul
		cmp dl, TOK_DIV
		je .div

		.mul:
			mov eax, [ebp-4]
			mov ebx, [ebp-9]
			imul eax, ebx
			mov [ebp-4], eax
			jmp .end1
		.div:
			mov eax, [ebp-4]
			mov ebx, [ebp-9]
			xor edx, edx
			div ebx
			mov [ebp-4], eax
			jmp .end1
	
		.end1:
			mov al, [token]
			mov [ebp-5], al
			jmp .loop
	.end:
	mov eax, [ebp-4]
	leave
	ret


; result - eax
expr:
	push ebp
	mov ebp, esp
	sub esp, 32
	
	call term
	mov [ebp-4], eax ; left

	mov al, [token]
	mov [ebp-5], al ; op

	.loop:
		mov dl, [ebp-5]
		call is_plus_minus
		test al, al
		jz .end

		call next

		call term
		mov [ebp-9], eax ; right
	
		mov al, [ebp-5]
		cmp al, TOK_PLUS
		je .plus
		cmp al, TOK_MINUS
		je .minus

		.plus:
			mov eax, [ebp-4]
			mov ebx, [ebp-9]
			add eax, ebx
			mov [ebp-4], eax
			jmp .end1
		.minus:
			mov eax, [ebp-4]
			mov ebx, [ebp-9]
			sub eax, ebx
			mov [ebp-4], eax
			jmp .end1
		.end1:
		mov al, [token]
		mov [ebp-5], al

		jmp .loop

	.end:
	mov eax, [ebp-4]
	leave
	ret

; result - eax
parse:
	call next
	call expr
	ret

_start:
	call request
	mov dword [pos], input

	call parse

	mov ebx, eax
	mov eax, SYS_EXIT
	int 0x80

if LINK
section '.data' writeable
end if

unknown_token: db "unknown token", 10
unknown_token_size =  $ - unknown_token
syntax: db "syntax error", 10
syntax_size =  $ - syntax
input: rb 1024
token: rb 1
token_value: rb 4
pos: rb 4
