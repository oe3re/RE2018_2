INCLUDE Irvine32.inc
INCLUDE macros.inc

BUFFER_SIZE = 256*256*30
sbuff = 3

.data
bufferIn BYTE BUFFER_SIZE DUP(? )
bufferOut BYTE 10 DUP(? )
inputImageName BYTE 80 DUP(0)
outputImageName BYTE 80 DUP(0)
inputImageHandle HANDLE ?
outputImageHandle HANDLE ?
spom BYTE sbuff DUP(? )
s DWORD ?
koef BYTE ?

bytesWritten DWORD ?
numBuffer BYTE 6 DUP(? )		; da moze sirina i visina da ima 5 cifara 
buffPtr DWORD 0
bytesRead DWORD 0
pixHeight DWORD 0
pixWidth DWORD 0
pixWidthScaled DWORD 0
pixHeightScaled DWORD 0
pixCount BYTE 0 				; je byte zato sto broji samo 1 red, tj od 1 do 50<2^8
pixCount1 DWORD 0				; broji u jednoj vrsti mora dword
pixCount2 DWORD 0				; broji kolone mora dword

x0 DWORD ?
y0 DWORD ?
xr DWORD ?
yr DWORD ?
xCount DWORD 0 					; pomocni brojac za x
yCount DWORD 0 					; pomocni brojac za y
pomPtr DWORD 0 					; pomocni brojac za ulaznu sliku
valueBuffer BYTE 4 DUP (?) 		;za smestanje vrednosti sa koordinate x0 y0

; flegovi
prepisuj BYTE 1
EOF_indicator BYTE 0
widthIndicator BYTE 1		
pixValueIndicator BYTE 1

.code
;procedura za vracanje intenziteta slike sa koordinatama x0,y0
;intenzitet se smesta u numBuffer
intenzitet proc
	push eax
	push edx
	
	mov ecx,0
	mov eax, 0
	mov xCount, eax
	mov eax, 0
	mov yCount, eax
	mov eax, buffPtr 	; pocetak ulazne slike
	mov pomPtr, eax 
pocetak_brojanja:
	mov edx, pomPtr
	mov al, [edx]
	cmp al, 20h 
	je povecaj_xCount
	cmp al, 0ah
	je nov_red
	jmp nastavak_brojanja
nov_red:
	inc pomPtr
	jmp pocetak_brojanja
povecaj_xCount:
	inc xCount
	inc pomPtr
	mov eax, xCount 	; provera da li xCount ide u nov red 
	cmp eax, pixWidth
	je resetuj_xCount
	jmp pocetak_brojanja
resetuj_xCount:			; nov red , xCount=0 yCount+1
	mov eax, 0
	mov xCount, eax
	inc yCount
	mov eax, yCount		; provera da li je yCount kraj
	cmp eax, pixHeight
	je kraj
	jmp pocetak_brojanja
nastavak_brojanja:
	mov eax, xCount
	cmp eax, x0
	je dobar_X
	jmp promasaj
dobar_X:
	mov eax, yCount
	cmp eax, y0
	je dobar_XiY
	jmp promasaj
promasaj:
	inc pomPtr
	jmp pocetak_brojanja
dobar_XiY:
	mov edx, pomPtr
	mov al, [edx]
	call IsDigit
	jnz kraj
	mov numBuffer[ecx], al
	inc ecx
	inc pomPtr
	jmp dobar_XiY
kraj:
	pop edx
	pop eax
	ret
intenzitet endp


;procedura za konverziju decimalnog broja u string
;smesta novi string u bafer sa pocetnom adresom u edi
intToString proc	
    push  edx
    push  ecx
    push  edi
    push  ebp
    mov   ebp, esp
    mov   ecx, 10
 pushDigits:
    xor   edx, edx        ; edx=0
    div   ecx             ; edx =ostatak=sledeca cifra
    add   edx, 30h        ; decimal + 30h = ascii 
    push  edx             ; push cifra
    test  eax, eax        ; ako je eax nula onda je gotovo 
    jnz   pushDigits
 popDigits:
    pop   eax
    stosb                 ; upisuje se samo al!!!, eax->(edi)
    cmp   esp, ebp        ; esp==ebp sve cifre su u numbuffer
    jne   popDigits
    pop   ebp
    pop   edi
    pop   ecx
    pop   edx     
	ret
intToString endp



main proc
	mWrite "Unesite ime ulazne slike: "
	mov edx, OFFSET inputImageName
	mov ecx, SIZEOF inputImageName
	call ReadString
	mWrite "Unesite ime izlazne slike: "
	mov edx, OFFSET outputImageName
	mov ecx, SIZEOF outputImageName
	call ReadString
; s = ?
	mWrite "s= "
	mov	edx, OFFSET spom
	mov	ecx, SIZEOF spom
	call ReadString
	mov ecx, LENGTHOF spom
	mov edx, OFFSET spom
	call ParseDecimal32
	mov s, eax
; smer, 1 za povecanje 0 za decimaciju
	mWrite <"1 za povecanje 0 za decimaciju:",0dh, 0ah>
	call ReadChar
	mov  koef, al
;provere ispravnosti
	mov edx, OFFSET inputImageName
	call OpenInputFile
	mov inputImageHandle, eax
	cmp eax, INVALID_HANDLE_VALUE
	jne create_output
	mWrite<"Neispravno ime ulaznog fajla", 0dh, 0ah>
	jmp close_files
create_output :
	mov  edx, OFFSET outputImageName
	call CreateOutputFile
	mov  outputImageHandle, eax
	cmp eax, INVALID_HANDLE_VALUE
	jne files_ok
	mWrite<"Neispravno ime izlaznog fajla", 0dh, 0ah>
	jmp close_files
files_ok :
	mov eax, inputImageHandle
	mov edx, OFFSET bufferIn
	mov ecx, BUFFER_SIZE
	call ReadFromFile
	jnc P2
	mWrite "Error u citanju fajla"
	call WriteWindowsMsg
	jmp close_files
; prepisivanje  P2
P2 :
	cld
	mov ecx, 3
	mov esi, OFFSET bufferIn
	mov edi, OFFSET bufferOut
	rep movsb
	mov  eax, outputImageHandle
	mov  edx, OFFSET bufferOut
	mov  ecx, 3					
	call WriteToFile			; u eax se upisuje 4 jer je 4 bajta upisano u izl fajl
	jc   error_writing
	add  bytesWritten, eax		;doda se 4 na 0
	mov buffPtr, esi
	mov widthIndicator, 1
	;read_char ucitava jedan znak i proverava se da li se 
	;ucitava sirina,duzina,intenzitet max, ili obrada
read_char:
	cmp EOF_indicator, 1
	je close_files
	mov edx, buffPtr
	mov al, [edx]
	cmp al, "#"
	je comment_sign
	cmp widthIndicator, 1
	je width_scaling
	cmp pixValueIndicator, 1
	je pix_value_prepisi
	cmp koef, 31h
	je obradaPovecanja
	jmp obradaSmanjivanja
width_scaling: 
	mov ecx,0
load_width:	
	mov edx, buffPtr
	mov al, [edx]
	call IsDigit
	jnz width_not_digit
	mov numBuffer[ecx], al
	inc ecx
	inc buffPtr
	jmp load_width	
width_not_digit:
	mov edx, OFFSET numBuffer
	call ParseDecimal32
	mov pixWidth, eax
	mov ebx, s
	mov edx,0 					; mora da se resetuje edx zato sto se deli EDX:EAX / EBX,tj EDX je high 
	cmp koef, 31h
	je povecanjedimenzijaW
	div ebx
	jmp nastavakW
povecanjedimenzijaW:
	mul ebx
nastavakW:
	mov pixWidthScaled , eax
	cmp eax, 10
	jb new_width_under10
	cmp eax, 100
	jb new_width_under100
	cmp eax, 1000
	jb new_width_under1000
	ja new_width_over1000
	inc ecx
	jmp widthnastavak
new_width_under10:
	mov ecx, 1
	jmp widthnastavak
new_width_under100:
	mov ecx, 2
	jmp widthnastavak
new_width_under1000:
	mov ecx, 3
	jmp widthnastavak
new_width_over1000:
	mov ecx, 4
	jmp widthnastavak
widthnastavak:
	mov edi, OFFSET numBuffer
	call intToString
	mov  numBuffer[ecx], 20h
	inc ecx
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    call WriteToFile
	jc   error_writing
    add  bytesWritten,eax	
	mov widthIndicator, 0
	inc buffPtr
height_scaling:
	mov ecx, 0
load_height:
	mov edx, buffPtr
	mov al, [edx]
	call IsDigit
	jnz height_not_digit
	mov numBuffer[ecx], al
	inc ecx
	inc buffPtr
	jmp load_height	
height_not_digit:	
	mov edx, OFFSET numBuffer
	mov numBuffer[ecx], 00h
	call ParseDecimal32
	mov pixHeight, eax
	mov ebx,s
	mov edx,0
	cmp koef, 31h
	je povecanjedimenzijah
	div ebx
	jmp nastavakH
povecanjedimenzijaH:
	mul ebx
nastavakH:
	mov pixHeightScaled, eax	
	cmp eax, 10
	jb new_height_under10
	cmp eax, 100
	jb  new_height_under100
	cmp eax, 1000
	jb new_height_under1000
	ja new_height_over1000
	jmp cont_height
new_height_under10:
	mov ecx, 1
	jmp cont_height
new_height_under100:
	mov ecx, 2
	jmp cont_height
new_height_under1000:
	mov ecx, 3
	jmp cont_height
new_height_over1000:
	mov ecx, 4
cont_height:
	mov edi, OFFSET numBuffer
	call intToString
	mov numBuffer[ecx], 0ah
	inc ecx
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    call WriteToFile
	jc   error_writing
    add  bytesWritten,eax	
	inc buffPtr
	jmp read_char
;kraj dela za prepisivanje i korekciju informacije o visini i sirini slike
comment_sign:
	inc bytesWritten
	inc buffPtr
	mov edx, buffPtr
	mov al, [edx]
	cmp al, 0ah
	jne comment_sign
	inc buffPtr
	jmp read_char
; kraj dela za obradu komentara
pix_value_prepisi:	
	mov ecx, 3
	mov esi, buffPtr
	mov edi, OFFSET numBuffer
	rep movsb
	mov buffPtr, esi
	inc buffPtr
	mov numBuffer[3], 0ah
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    mov  ecx, 4
    call WriteToFile
	jc   error_writing
    add  bytesWritten,eax	
	mov pixValueIndicator, 0
	jmp read_char
; kraj dela za prepisivanje informacije o maksimalnoj vrednosti piksela	
;	POCETAK OBRADE 

obradaPovecanja:
	mov eax,0 
	mov pixCount1, eax
	mov pixCount2, eax	
pocetak_obradePOV:
	xor edx, edx
	mov ebx,s 
	mov eax, pixCount1 
	div ebx					; eax=x'/s 
	mov x0, eax				; x0=eax
	mov xr, edx				; xr=x'-x0*s ostatak pri deljenju	
	xor edx, edx
	mov eax, pixCount2
	div ebx
	mov y0,eax
	mov yr,edx
	mov eax, xr
	shl eax, 1				; mnozenje xr sa 2
	cmp eax, s
	ja x0_povecava_za1
	jmp nastavakx
x0_povecava_za1:
	inc x0
	mov eax, x0
	cmp eax, pixWidth
	je x0_vece_od_W
	jmp nastavakx
x0_vece_od_W:
	dec x0
	jmp nastavakx
nastavakx:
	mov eax, yr
	shl eax, 1				; mnozenje yr sa 2
	cmp eax, s
	ja y0_povecava_za1
	jmp nastavaky
y0_povecava_za1:
	inc y0
	mov eax, y0
	cmp eax, pixHeight
	je y0_vece_od_H
	jmp nastavaky
y0_vece_od_H:
	dec y0
	jmp nastavaky
nastavaky:
	call intenzitet			;intenzitet x0,y0 u numbufferu
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    call WriteToFile
	jc   error_writing
	mov numBuffer[0], 20h	;razmak posle svakog broja
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    mov  ecx, 1
	call WriteToFile
	jc   error_writing
	inc pixCount			
	mov al, pixCount
	cmp al, 20
	je upisi_nov_redPOV
	jmp ne_novi_redPOV
upisi_nov_redPOV:
	mov numBuffer[0], 0ah
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    mov  ecx, 1
    call WriteToFile
	jc   error_writing
	mov al, 0
	mov pixCount, al
ne_novi_redPOV:
	inc pixCount1
	mov eax, pixCount1
	cmp eax, pixWidthScaled
	je reset_pixCount1
	jmp pocetak_obradePOV
reset_pixCount1:
	mov eax, 0
	mov pixCount1, eax
	inc pixCount2
	mov eax, pixCount2
	cmp eax, pixHeightScaled
	je close_files
	jmp pocetak_obradePOV

obradaSmanjivanja:
	mov eax,0 
	mov pixCount1, eax
	mov pixCount2, eax
pocetak_obradeDEC:
	xor edx, edx
	mov ebx,s
	mov eax, pixCount1 
	mul ebx
	mov x0,eax			;koordinata x0 je koordinata u originalnoj slici
	xor edx, edx
	mov ebx,s
	mov eax, pixCount2
	mul ebx
	mov y0, eax
	call intenzitet		;intenzitet x0,y0 u numbufferu
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    call WriteToFile
	jc   error_writing
	mov numBuffer[0], 20h	;razmak posle svakog broja
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    mov  ecx, 1
	call WriteToFile
	jc   error_writing
	inc pixCount		;poveca se pixCount
	mov al, pixCount
	cmp al, 20
	je upisi_nov_redDEC
	jmp ne_novi_redDEC
upisi_nov_redDEC:
	mov numBuffer[0], 0ah
	mov  eax, outputImageHandle
    mov  edx, OFFSET numBuffer
    mov  ecx, 1
    call WriteToFile
	jc   error_writing
	mov al, 0
	mov pixCount, al
ne_novi_redDEC:
	inc pixCount1
	mov eax, pixCount1
	cmp eax, pixWidthScaled
	je reset_pixCount1DEC
	jmp pocetak_obradeDEC
reset_pixCount1DEC:
	mov eax, 0
	mov pixCount1, eax
	inc pixCount2
	mov eax, pixCount2
	cmp eax, pixHeightScaled
	je close_files
	jmp pocetak_obradeDEC
error_writing:
	mWrite <"Error prilikom upisivanja ", 0dh, 0ah>
; zatvaranje fajlova i izlazak
close_files :
	mWrite < 0ah ,"Kraj obrade ", 0dh, 0ah>
	mov eax, outputImageHandle
	call CloseFile
close_input_file :
	mov eax, inputImageHandle
	call CloseFile
quit:
exit
main endp
end main