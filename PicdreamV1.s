
;******************************************************************************
;                                                                             *
;    Author              :  Alain Fort                                        *
;    Filename            :  PicDreamII_EEPROM.s                                *
;    Date                :  25/10/2013                                        *
;    horloge de base FCY = 16MHz	     								  *
;    File Version        :  1.00                                              *
;    Source basée sur PICDREAM 									              *
;    PIC 24F16KA101 avec Xtal à 8MHz et horloge Fcy =16 MHz soit 16MIPS	  *
;******************************************************************************
; sync RB0  PORTB,#0
; A4, A1 et A0 pour les sorties Rouge Vert et Bleu
; Ligne        = 64u = 1024 cycles
; 1/2 ligne    = 32u = 512 cycles
; Front porch  = 1,5u = 24 cycles  
; Synchro      = 4,75u = 76 cycles 
; Blancking    = 5,8u = 93 cycles 
;
; Sync  RA6 broche  14
; Rouge RA4 broche 10
; Vert  RA1 broche 3
; Bleu  RA0 Broche 2
;
;
; si Fixe=1, pas de scrolling de texte
; Ce programme se range en mémoire en 0x0200
; Fonctionne et interfacé avec le programme PicDreamII.c
; 
;          .equ __24F16KA101,1
 
   
 .include "p24F16KA101.inc"

;**************************************************************************
;	Device Configuration
;		config __FGS, GCP_OFF    	    	; Set Code de Protection Off
;		config __FOSCSEL, FNOSC_PRIPLL      ; Oscillateur primaire
;		config __FOSC, POSCMD_XT            ; oscillateur XT seul
;		config __FWDT, FWDTEN_OFF           ; Watchdog Timer non activé
;		config __FPOR, FPWRT_PWR128         ; POReset de 128 millisecondes
;..............................................................................
;Global Declarations:
;..............................................................................

;.org 0x0200


_Mire:
    
.global _Mire          ;The label for the first line of code.
.global _FixeHaut
.global _FixeBas
.global _Fond1
.global _Fond2
.global _Coulchar1   ; couleur ligne 1
.global _Coulchar2   ; couleur ligne 2
;.global _MireString  ; string de test en assembleur
.global _Bars
.global _Shift    ; decalage en cours de  la ligne du haut
.global _ShiftBas ; decalage en cours de  la ligne du bas
.global _FixeLocal ; decalage en cours de  la ligne du bas
.global _FixeLocalBas ; decalage en cours de  la ligne du bas

.global ___U1RXInterrupt  ;  Declare U1RXInterrupt ISR name global
.global __reset

    ;    .global __T1Interrupt    ;Declare Timer 1 ISR name global

;..............................................................................
;Constants stored in Program space
;..............................................................................

;     .section .myconstbuffer, code
.palign 2                ;Align next word stored in Program space to an
                                 ;address that is a multiple of 2
.equ sync,PORTB  ; RB0 broche 4
;.equ Blanc,#0B1110000000
;.equ Cyan, #0B1010000000
;.equ Noir, #0B0000000000
;.equ Rouge,#0B1000000000 
;.equ Bleu, #0B0010000000
;.equ Vert, #0B0100000000

.text                             ;debut de la section de code

; ******************************************************************************
;                             RAM DATA non initialisée
;****************************   ************************************************

.bss        ;RAM DATA non initialisée
.align	2 

TAscii: .space 32  ; RAM représentant le texte en ascii des lettres visibles sur la ligne haute video en cours
               ; TAscii change à chaque fois que les caractères se déplacent d'un octet.
TVideo: .space 32  ; RAM espace sur écran pour les octets de la ligne haute vidéo en cours
TAscii2:.space 32  ; RAM espace pour les caractères ascii des lettres visibles sur la ligne basse video en cours
TVideo2:.space 32 ; RAM espace sur écran pour les octets de la ligne basse vidéo en cours

;_Fond: .space 2
;_FixeHaut: .space 2 ; variable de scrolling/fixe de la ligne haute
;_FixeBas: .space 2 ; variable de scrolling/fixe de la ligne basse
;_Coulchar1: .space 2
;_Coulchar2: .space 2 
;_Fond2: .space 2
;_Fond1: .space 2
;_Bars: .space 2

FixeLocal: .space 2 ; variable de scroll/fixe de la routine lineshift
FixeLocalBas: .space 2 ;
 

Delta2Bas  : .space 2
Delta1     : .space 2
Delta2H    : .space 2 
 
;Shift: .space 2 ; valeur du scroll horizontal en nombre de caractères
;ShiftBas: .space 2
Trame: .space 2
;Cpt_5sec: .space 2 ; pour saut au C
Flag: .space 2
FlagBas: .space 2
Lineloc:.space 2 ; variable decompteur par 4 pour répétér 4 fois
        ; la meme ligne en affichage
i: .space 2
Count: .space 2  ; nombre de ligne demandées dans la routine
Nlines:.space 2   ; numéro de ligne ; incrementé en fin de ligne = on commence
        ; chaque ligne avec le bon numéro de ligne

.text	;INDISPENSABLE !!! 
;IEC0bits.U1RXIE = 1
MOV  #0,W0
;MOV  W0,TRISA ; BITS 0 à 4 du PORTA en sortie sur le PIC24F16KA102
;BSET TRISB,#2   ;TRISBbits.TRISB2 = 1 ; entrée UART RX en RB2 INDISPENSABLE !!

MOV  W0,Trame
MOV  W0,Flag
MOV  #4,W0       ; 3
MOV  W0,Lineloc ; 4 chargement de 4
;MOV  #1,W0       ;
;MOV  W0,_Shift     ;A laisser à 1 pour que Fixe fonctionne bien au reset .

;<editor-fold defaultstate="collapsed" desc="Début trame 1">
Trame1: ; 5 demi lignes de pre egalisation
;{
		BCLR  sync,#0     	; 1  ; 1/2 ligne = 32us = 512 cycles  : Ligne 1
        Repeat #431        ; 433repeat = 27us
    	NOP  				;  434
        ;NOP ; xxxx
        Inc Trame           ;  435
		BSET    sync,#0		;  436
        repeat #74 	     	;  511
		NOP			        ;  512

        BCLR	sync,#0		; 1	; début de 1/2 ligne sync =0 Sync
	    Repeat  #431      	; 433
    	NOP					; 434
		BSET	sync,#0		; 436
        repeat	#70 		; 507
		NOP					; 508
        CLR Nlines			; 509
        INC Nlines			; 510
        NOP					; 511
        INC Nlines	        ; 512 Nlines = 2

        BCLR	sync,#0		; 1	; début de 1/2 ligne sync =0 Sync    Ligne 2
	    Repeat	#432      	; 434 repeat #106 ;
    	NOP  				; 435
		BSET	sync,#0		; 436 synchro à 1
        repeat	#74 		; 511
		NOP					; 512

        BCLR	sync,#0		; 1	; début de 1/2 ligne sync =0 Sync
	    Repeat	#432      	; 434
    	NOP  				; 435
		BSET	sync,#0		; 436 synchro à 1
        repeat	#74 		; 510 on repète 148 fois = temp synchro
        INC Nlines          ; 512

        BCLR	sync,#0		; 1	; début de 1/2 ligne sync =0 Sync    Ligne 3
	    Repeat	#432      	; 434
    	NOP  				; 435
		BSET	sync,#0		; 436
        repeat	#74 		; 511 synchro
		NOP					;} 512

Egalisation:; 5 Impulsions d'égalisation, débutent à 0 pendant 2,3525 us
            ;(1/2 ligne = 32us = 512 cycles)
		BCLR	sync,#0	; 1	; fin de ligne sync =0 Sync 2,3524 us soit 76 cycles
        REPEAT  #34 		; 36  durée à 0 = 2,35us = 77 cycles avec le BCLR
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 510
        INC Nlines          ; 512

		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync     ligne 4
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        INC     Nlines      ; 512       Nlines =5

	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync     ligne 5
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
        REPEAT  #34 		; 36
        NOP 				; 37  Durée à 0 = 77 cycles
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        INC     Nlines      ;}  512   fin ligne 5

T1_Lnoires_1:       ; T1 ligne X à Y  = 38 lignes noires Lignes 6 à 42
;{
		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	 	MOV	    #38,W0		; 2 ;  38 lignes
   	    MOV 	W0,Count    ; 3
		CALL	BlkLns		;;} ;4 5 retour à CALL = 2cycles Fin ligne 39
;</editor-fold>

T1_Prepa_TextHaut:    ; Ligne de preparation des données Ligne 43
;{
    BCLR	sync,#0  ; 1
    repeat  #70      ; 72
    NOP              ; 73
    Call Prepa_TextHaut ;} 74 75

T1_28L_Texte_Haut:  ; 44 à 72              
;{  
        BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
        ;
        MOV 	_FixeHaut,W0
        MOV 	W0,FixeLocal
        NOP
        NOP                  ; 5
		CALL    LinshiftHaut	; 6 et 7
        ;} le retour est fait par Lineshift à 1024
   
T1_noires_2:        ; 73 à 82 lignes noires 
;{ 
  		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync        Lignes  73 à 82
	 	MOV	    #10,W0		; 2 on met #10 pour génerer 10 lignes
   	    MOV 	W0,Count    ; 3
		CALL	BlkLns		;} ; CALL = 2cycles
 
T1_couleur:         ; 83 à 242  
;{  
      	BCLR	sync,#0		; 1	fin de ligne sync =0 Sync
	 	MOV	    #144,W0		; 2 163  lignes
    	MOV 	W0,Count   ;  3
		CALL	Colines		;} ; retour à N x2048

T1_SMPTE:         ; lignes 409 à 568
;{
        BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	 	MOV	    #19,W0		; 2 163 lignes
    	MOV 	W0,Count   ;  3
		CALL	SMPTElines		;} ; retour à N x2048

T1_noires_3:        ; 243 à 258   14 lignes 
;{
	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	 	MOV	    #10,W0		; 2 10 lignes
   	    MOV 	W0,Count    ; 3
		CALL	BlkLns		;;} ; retour à  ;CALL = 2cycles

T1_Prepa_Texte_Bas:  ; Ligne de preparation des données Ligne 43
;{
   		BCLR	sync,#0  ; 1
   		repeat  #70      ; 72
   		NOP              ; 73
    	Call Prepa_TextBas ; 1024  ;};

/* T1_noires_28_BAS:        ; 243 à 258   14 lignes
;{
	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	 	MOV	    #28,W0		; 2 on met #15 pour génerer 15 lignes
   	    MOV 	W0,Count    ; 3
		CALL	BlkLns		;;} ; retour à  ;CALL = 2cycles */

T1_28L_Texte_Bas: ; 259 à 287                  
       BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
		MOV 	_FixeBas,W0  ; fixe ou scroll
       MOV 	W0,FixeLocalBas
	 	NOP
		NOP
		CALL    LinshiftBas	; retour après 28 lignes de 1024 ;};

;<editor-fold defaultstate="collapsed" desc="Fin Trame 1">
T1_noires_4:        ; 288 à 312    26 lignes
;{
	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	 	MOV	    #26,W0		; 2 on met #26 pour génerer 26
   	    MOV 	W0,Count    ; 3
		CALL	BlkLns		;} ; CALL = 2cycles  . Fin ligne 310

Postega:            ; Post égalisation
		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync    Début de ligne 311
        REPEAT  #34 		; 36
        NOP					; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne syn début de ligne 312
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512  Fin ligne 312

		BCLR	sync,#0		; 1	; fin de ligne syn début de ligne 313
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512   Fin ligne 312,5
;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Début trame 2">
;T2
 Trame2:BCLR  sync,#0 	; 1   1/2 ligne = 32us =  1024  cycles  seconde 1/2 313e ligne
   		;BSET PORTB,#15  ; 2 syncro trame sur RB9 pour oscilloscope 2
    	;BCLR PORTB,#15	; 3
        Repeat #432         ; 434  repeat #103+1 = 106 = 27us :871
    	NOP  				; 435
		BSET	sync,#0		; 436
        repeat #74 		    ; 511 on repete 174 fois = temp synchro = 5 micro
                ; seconde soit 176 total instruction ;
        ;Inc Trame		    ; 512 fin ligne 313
        NOP  ;xxxxx

        BCLR	sync,#0		; 1	; début de 1/2 ligne sync =0 Sync    Ligne 314
	    Repeat	#432      	; 434
    	NOP  				; 435
		BSET	sync,#0		; 436
        repeat	#74 		; 511 synchro à 1
		NOP					; 512

        BCLR	sync,#0		; 1	; début de 1/2 ligne sync =0 Sync
	    Repeat	#432      	; 434
    	NOP  				; 435
		BSET	sync,#0		; 436 synchro à 1
        repeat	#74 		; 511
		NOP					; 512 Fin Ligne 314

        BCLR	sync,#0		; 1	; début de 1/2 ligne sync =0 Sync    Ligne 315
	    Repeat	#432      	; 434
    	NOP  				; 435
		BSET	sync,#0		; 436 synchro à 1
        repeat	#74 		; 511
		NOP					; 512 fin ligne

        BCLR	sync,#0		; 1	; début de 1/2 ligne sync =0 Sync
	    Repeat	#432      	; 434
    	NOP  				; 435
		BSET	sync,#0		; 436 synchro à 1
        repeat	#74 		; 511
		NOP					; 512 Fin ligne 315
 ;T2
Prega1316:
		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync        Ligne 316
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync        Ligne 317
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync    
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472  	; 511
        NOP 				;;} 512 Fin ligne 317

        BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync        Ligne 318
        REPEAT  #34 		; 36 ; avec synchro courte
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512
        REPEAT  #510 		; 1023
        NOP 				; 1024

T2_noires_1:        ;319 à  = 37 lignes noires
;{
    	BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	 	MOV	    #37,W0		; 2 on met #39 pour génerer 39 lignes
   	    MOV 	W0,Count    ; 3
		CALL	BlkLns		;;} 4 5   ; CALL = 2cycles
;</editor-fold>

T2Prepa_Texte_Haut:     ; Ligne de preparation des données Ligne 43
;{
    BCLR	sync,#0  ; 1
    repeat  #70      ; 72
    NOP              ; 73
    Call Prepa_TextHaut ;} 74 75

T2_28L_Texte_Haut:  ; haut
;{                       
        BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
        MOV 	_FixeHaut,W0 ; scrolling ?
        MOV 	W0,FixeLocal
        NOP
        NOP                  ;5
	CALL    LinshiftHaut	;} retour à N x2039 ;  6 7
                  
T2_noires_2:        ;  ligne 318 à 335 = 10 ligne noires haut               408
;{
    	BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	MOV	#10,W0		; 2 on met #10 pour génerer 10 lignes
   	MOV 	W0,Count    ; 3
	CALL	BlkLns		;} retour à  ;CALL = 2cycles
	
T2_couleur:         ; lignes 409 à 568                        
;{ 
        BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	MOV	#144,W0		; 2 163 lignes
    	MOV 	W0,Count   ;  3
	CALL	Colines		;} ; retour à N x2048

T2_SMPTE:         ; lignes 409 à 568                        
        BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	MOV	#19,W0		; 2 163 lignes
    	MOV 	W0,Count    ; 3
	CALL	SMPTElines	; retour à N x2048

T2_noires_3:        ;  10 Lignes     555 à 569
	BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	MOV	#10,W0		; 2 on met #10 pour génerer 10 lignes
   	MOV 	W0,Count    ; 3
	CALL	BlkLns		; retour à  ;CALL = 2cycles
	;	BSET PORTB,#15  ; 2 syncro trame sur RB9 pour oscilloscope 2
    ;	BCLR PORTB,#15	;} 3

T2_Prepa_TexteBas:    ; Ligne de preparation des données Ligne 43
    BCLR	sync,#0  ; 1
    repeat	 #70      ; 72
    NOP			; 73
    Call Prepa_TextBas ; 1024

/*T2_noires_28Bas:        ;  28 Lignes     555 à 569
;{
	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	 	MOV	    #28,W0		; 2 on met #14 pour génerer 14 lignes
   	    MOV 	W0,Count    ; 3
		CALL	BlkLns		; retour à  ;CALL = 2cycles */

T2_28L_Texte_Bas: ;   28 lignes déroulant bas ligne   570  à 601
        BCLR	sync,#0		; 1	; Fin de ligne sync =0 Sync
		MOV 	_FixeBas,W0
        MOV 	W0,FixeLocalBas
		NOP
	    NOP
		CALL   LinshiftBas	; retour à N 2028 + 2039 ;  19 et 20

;<editor-fold defaultstate="collapsed" desc="Fin Trame 2">
T2_noires_4:        ; T2  18 lignes Noires  lignes    602 à 622
	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
	 	MOV	    #26,W0		; 2 on met #18 pour génerer 18 lignes (6-1)
   	    MOV 	W0,Count    ; 3
		CALL	BlkLns		;} ; retour à  ;CALL = 2cycles Fin ligne 622

ligne623:
		BCLR	sync,#0		; 1	; 1/2 ligne avec bonnne syncro 623
        REPEAT  #72 		; 74
        NOP 				; 75
		BSET	sync,#0		; 76	'synchro normale
        REPEAT  #434 		; 511
        NOP 				;} 512

Postegal623:
	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync

        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38	 'synchro réduite
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync     624
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472 		; 511
        NOP 				; 512

		BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync    / fin Ligne 624
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #472  		; 511
        INC     Nlines      ; 512    Nlines = 625

	    BCLR	sync,#0		; 1	; fin de ligne sync =0 Sync
        REPEAT  #34 		; 36
        NOP 				; 37
		BSET	sync,#0		; 38
        REPEAT  #470    	;509
        NOP                 ;510
        BRA     Trame1      ;511 512   Fin ligne 625 et retour au début
;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Sub LinshiftHaut">
; Sub  ROUTINE DE DECALAGE DE LIGNE    LINSHIFTHaut de 28 lignes (7x4)
Loop6:  NOP                 ; 1023
        NOP                 ; 1024   Fin de ligne

        BCLR     sync,#0    ; 1   ***  Début synchro quand on reboucle ***
        Repeat   #4         ; 6
        NOP                 ; 7  *** ENTREE de la routine après 20 cycles ***

LinshiftHaut:CP0 Lineloc  ;1(8e instruction)  Comparaison de Lineloc à 0
        BRA NZ,TITI   ;2 3    On sort si Lineloc different de 0
        MOV #3,W7     ;3      On charge 3 dans Lineloc pour avoir 4 lignes affichées indentiques 4,3,2,1
        MOV W7,Lineloc;4      On recharge 3 dans Lineloc si linloc=0
        INC W2,W2     ;5      +1 dans le pointeur de ligne caractere W2 toutes les 4 lignes (4lignes identiques)
        MOV Trame,W4  ;6
        CP  W4,#15    ;7      Recherche de la 19e trame
        BRA LE,TITI2  ;8 9    Si trame < 19 on sort
        NOP  ; CLR Trame     ;9      Si trame > 19 alors Trame=0   (400 ms) (RAZ du shift fin)
        MOV FixeLocal,W4   ;10
        CP  W4,#1     ;11     Est ce fixe ?
        BRA EQ,TI3    ;12 13  Oui
        INC Flag      ; 13 permet d'increment Shift dans la routine de préparation (pour synchro affichage)
                      ; 	  Non On incrémente Shift (de 1 caractere) toutes les 16 x 2 trames
        BRA TITI1     ;14 15  Vers Fin
TITI:   DEC Lineloc   ;4      On décremente lineloc(c'est pour cela que on mets 4 en entrant)
        NOP ;5
        NOP ;6
        NOP ;7
        NOP ;8
        NOP ;9
TITI2:  NOP ;10
        NOP ;11
        NOP ;12
        NOP ;13
TI3:    NOP ;14
        NOP ;15
TITI1:  NOP ;16  Duree 16 cycles  ; T=36

;*******lecture des 9 caractères du Message ASCII durée  cycles*********

		Repeat #17
		NOP

 		MOV     #TVideo, W14     ; 40  adresse table RAM des bits à écrire sur l'écran  ; aff
		MOV     #TAscii, W13     ; adresse table RAM des caracteres du message ecran de la trame en cours
;1
		MOV      [W13++],W4   ; 1 adresse (non finale) de l'octet dans W4
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4  lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5 lecture du caractere à afficher dans W14 indexé
;2
		MOV      [W13++],W4   ; 1 adresse (non finale) de l'octet dans W4
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;3
		MOV      [W13++],W4   ; 1 adresse (non finale) de l'octet dans W4
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;4
		MOV      [W13++],W4   ; 1
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;5
		MOV      [W13++],W4   ; 1
		ADD	     W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5 lecture du caractere à afficher dans W14 indexé

;*******************************************************************************************
Suite: BSET	     sync,#0  ; 76 SYNC SYNC SYNC  SYNC  NE pas changer !!!!!!!!!!!!!!!!!!!!
;*******************************************************************************************

;6
		MOV      [W13++],W4   ; 1
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset vertical W2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5 lecture du caractere à afficher dans W14 indexé
;7
		MOV      [W13++],W4   ; 1
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;8
		MOV      [W13++],W4   ; 1
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;9
		MOV      [W13++],W4   ; 1
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;10
		MOV      [W13++],W4   ; 1
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;11
		MOV      [W13++],W4   ; 1
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;12
		MOV      [W13++],W4   ; 1
		ADD		 W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5 lecture du caractere à afficher dans W14 indexé

       ;MOV _Fond1,W0       ; T 124     ;couleur de Fond du texte NE PAS DEPLACER
       ;MOV W0,PORTA        ; T=125
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		MOV #80,W0 		    ; 77
		MOV Trame,W4        ; 78 Trame dans W4
		CP0 FixeLocal       ; 79 compare fixe à zéro
		BRA EQ, SL22        ; 80 81  Test Fixe / Scroll
		CLR W4              ; 81
SL22:   SL  W4,#2,W4        ; 82 SL  Multiplication par 2  2xTrame < 80 (vitesse de déplacement)
		MOV W4,Delta2H      ; 83 delta2 = retard fin de ligne
		SUB W0,W4,W4        ; 84 Delta1 = 80 - delta2 = retard début de ligne dans W4
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

 ;*************************************************************************************************


        REPEAT #12
        NOP
        MOV _Fond1,W0    ; T 124     ;couleur de Fond du texte NE PAS DEPLACER
        MOV W0,PORTA    ; T=125

        REPEAT W4                 ; retard Delta1 (Delta1+Delta2=165 cycles pris en compte plus bas)
        NOP      

        MOV      #TVideo, W14     ; 40

;1****************************************************************************************************
;   73 cycles par caractere   10 caractere = 73 x11 = 730 cycles
Affiche:MOV [W14++],W4  ; 1    durée= 2 cycles  ' on range l'octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractère

AFF_CAR0:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0 :Boucle de 10 cycles
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin00     ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4  W0 à la couleur du Fond si C=0
Fin00:  MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP             ; 6
        DEC W9,W9       ; 7  (a t'on décalé 8 bits ?) : COMPARE W9 #9
        BRA NZ,AFF_CAR0 ; 8 9 non             ;
;2***************************************************************************************************
        MOV [W14++],W4  ; 1    durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR1:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin11     ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4 W0 à la couleur du Fond si C=0
Fin11:  MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP			    ; 6
        DEC W9,W9       ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR1 ; 8 9 non
;3*************************************************************************************************
        MOV [W14++],W4  ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR2:MOV _Coulchar1,W0  ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin12     ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0     ; 4  W0 à la couleur du Fond si C=0
Fin12:  MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP			    ; 6
        DEC W9,W9       ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR2 ; 8 9 non
;4***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR3:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin13    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin13: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR3; 8 9 non
;5***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR4:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2 rotate left W4
        BRA C,Fin14    ; 3 4 Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin14: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR4; 8 9 non
;6***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR5:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin15    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin15: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR5; 8 9 non
;7***************************************************************************************************
        MOV [W14++],W4 ; 1    durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR6:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin16    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin16: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR6; 8 9 non
;8***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR7:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin17    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin17: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR7; 8 9 non
;9***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR8:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin18    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin18: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR8; 8 9 non
;10***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR9:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin19    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin19: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR9; 8 9 non
;11***************************************************************************************************
        MOV [W14++],W4  ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR10:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin110    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0     ; 4  W0 à la couleur du Fond si C=0
 Fin110:MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP			    ; 6
        DEC W9,W9       ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR10; 8 9 non
;12***************************************************************************************************
        MOV [W14++],W4  ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR11:MOV _Coulchar1,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin111    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond1,W0     ; 4  W0 à la couleur du Fond si C=0
 Fin111:MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP			    ; 6
        DEC W9,W9       ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR11; 8 9 non
         
        MOV Delta2H,W4    ; (total des deltas = 80 + 4 = 84 )
        Repeat W4        ;
        NOP
   
 finlinn:
        MOV		_Noir,W0    ; 1018
	    MOV		W0,PORTA	; 1019  on fait le noir
        repeat #17          ; durée noir avant fin de ligne
        NOP
		DEC	  	Count		; 1020  ; nombre de lignes
		BRA 	NZ,Loop6	; 1021 1022  on retrace une ligne
		RETURN				; 1022 1023 1024  (return prend 3 cycles) ;} Fin Linshift

;</editor-fold>
 
;<editor-fold defaultstate="collapsed" desc="Sub LinshiftBas">
; Sub  ROUTINE d'Affichage de ligne video texte    LINSHIFTBAS
Loop6Bas:NOP              ; 1023
        NOP                 ; 1024

        BCLR     sync,#0    ; 1   ***  Début synchro quand on reboucle ***
        Repeat   #4         ; 6
        NOP                 ; 7  *** ENTREE de la routine après 20 cycles ***

LinshiftBas:CP0 Lineloc  ;1(8e instruction)  Comparaison de Lineloc à 0
        BRA NZ,TITIBas   ;2 3    On sort si Lineloc different de 0
        MOV #3,W7     ;3      On charge 3 dans Lineloc pour avoir 4 lignes affichées indentiques 4,3,2,1
        MOV W7,Lineloc;4      On recharge 3 dans Lineloc si linloc=0
        INC W2,W2     ;5      +1 dans le pointeur de ligne caractere W2 toutes les 4 lignes (4lignes identiques)
        MOV Trame,W4  ;6
        ;RRC W4,W4   ;   **********************************
        CP  W4,#15    ;7      Recherche de la 19e trame
        BRA LE,TITI2Bas  ;8 9    Si trame < 19 on sort
        NOP  ; CLR Trame     ;9      Si trame > 19 alors Trame=0   (400 ms) (RAZ du shift fin)
        MOV FixeLocalBas,W4   ;10
        CP  W4,#1     ;11     Est ce fixe ?
        BRA EQ,TI3Bas    ;12 13  Oui
        INC FlagBas      ; 13 permet d'increment Shift dans la routine de préparation (pour synchro affichage)
        ; INC _Shift     ;13 	  Non On incrémente Shift (de 1 caractere) toutes les 16 x 2 trames
        BRA TITI1Bas     ;14 15  Vers Fin
TITIBas:DEC Lineloc   ;4      On décremente lineloc(c'est pour cela que on mets 4 en entrant)
        NOP ;5
        NOP ;6
        NOP ;7
        NOP ;8
        NOP ;9
TITI2Bas:NOP ;10
        NOP ;11
        NOP ;12
        NOP ;13
TI3Bas: NOP ;14
        NOP ;15
TITI1Bas:  NOP ;16  Duree 16 cycles  ; T=36

;*******lecture des 9 caractères du Message ASCII durée  cycles*********

		Repeat #17
		NOP

 		MOV     #TVideo2, W14     ; 40  adresse table RAM des bits à écrire sur l'écran  ; aff
		MOV     #TAscii2, W13     ; adresse table RAM des caracteres du message ecran de la trame en cours
;1
		MOV      [W13++],W4   ; 1 adresse (non finale) de l'octet dans W4
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4  lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5 lecture du caractere à afficher dans W14 indexé
;2
		MOV      [W13++],W4   ; 1 adresse (non finale) de l'octet dans W4
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;3
		MOV      [W13++],W4   ; 1 adresse (non finale) de l'octet dans W4
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;4
		MOV      [W13++],W4   ; 1
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;5
		MOV      [W13++],W4   ; 1
		ADD	    W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5 lecture du caractere à afficher dans W14 indexé

;*******************************************************************************************
SuiteBas: BSET	     sync,#0  ; 76 SYNC SYNC SYNC  SYNC  NE pas changer !!!!!!!!!!!!!!!!!!!!
;*******************************************************************************************

;6
		MOV      [W13++],W4   ; 1
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset vertical W2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5 lecture du caractere à afficher dans W14 indexé
;7
		MOV      [W13++],W4   ; 1
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;8
		MOV      [W13++],W4   ; 1
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;9
		MOV      [W13++],W4   ; 1
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;10
		MOV      [W13++],W4   ; 1
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;11
		MOV      [W13++],W4   ; 1
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5lecture du caractere à afficher dans W14 indexé
;12
		MOV      [W13++],W4   ; 1
		ADD		W4,W2,W0    ; 2 W4     ; addition de l'offset verticalW2 (0à7) de la ligne (à afficher) du caractère
		TBLRDL.B [W0],W4 	    ; 3 4 lecture table(Low byte)avec le pointeur
		MOV       W4,[W14++]  ; 5 lecture du caractere à afficher dans W14 indexé

		;MOV _Fond2,W0    ; T 124     ;couleur de Fond du texte NE PAS DEPLACER
        ;MOV W0,PORTA    ; T=125
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		MOV #80,W0 		; 77
		MOV Trame,W4        ; 78 Trame dans W4
		CP0 FixeLocalBas            ; 79 compare fixe à zéro
		BRA EQ, SL22Bas        ; 80 81  Test Fixe / Scroll
		CLR W4              ; 81
SL22Bas:SL  W4,#2,W4        ; 82 SL  Multiplication par 2  2xTrame < 80 (vitesse de déplacement)
		MOV W4,Delta2Bas       ; 83 delta2 = retard fin de ligne
		SUB W0,W4,W4        ; 84 Delta1 = 80 - delta2 = retard début de ligne dans W4
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

 ;*************************************************************************************************
        REPEAT #12
        NOP
        MOV _Fond2,W0    ; T 124     ;couleur de Fond du texte NE PAS DEPLACER
        MOV W0,PORTA    ; T=125

        REPEAT W4                 ; retard Delta1 (Delta1+Delta2=165 cycles pris en compte plus bas)
        NOP

      
        MOV      #TVideo2, W14     ; 40

;1****************************************************************************************************
;   73 cycles par caractere   10 caractere = 73 x11 = 730 cycles
AfficheBas:MOV [W14++],W4  ; 1    durée= 2 cycles  ' on range l'octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractère

AFF_CAR0Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0 :Boucle de 10 cycles
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin00Bas     ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4  W0 à la couleur du Fond si C=0
Fin00Bas:  MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP             ; 6
        DEC W9,W9       ; 7  (a t'on décalé 8 bits ?) : COMPARE W9 #9
        BRA NZ,AFF_CAR0Bas ; 8 9 non             ;
;2***************************************************************************************************
        MOV [W14++],W4  ; 1    durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR1Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin11Bas     ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4 W0 à la couleur du Fond si C=0
Fin11Bas:  MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP			    ; 6
        DEC W9,W9       ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR1Bas ; 8 9 non
;3*************************************************************************************************
        MOV [W14++],W4  ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR2Bas:MOV _Coulchar2,W0  ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin12Bas     ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0     ; 4  W0 à la couleur du Fond si C=0
Fin12Bas:  MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP			    ; 6
        DEC W9,W9       ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR2Bas ; 8 9 non
;4***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR3Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin13Bas    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin13Bas: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR3Bas; 8 9 non
;5***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR4Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2 rotate left W4
        BRA C,Fin14Bas    ; 3 4 Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin14Bas: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR4Bas; 8 9 non
;6***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR5Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin15Bas    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin15Bas: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR5Bas; 8 9 non
;7***************************************************************************************************
        MOV [W14++],W4 ; 1    durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR6Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin16Bas    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin16Bas: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 8 bits ?)
        BRA NZ,AFF_CAR6Bas; 8 9 non
;8***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR7Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin17Bas    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin17Bas: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR7Bas; 8 9 non
;9***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR8Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin18Bas    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin18Bas: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR8Bas; 8 9 non
;10***************************************************************************************************
        MOV [W14++],W4 ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9      ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR9Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4      ; 2  rotate left W4
        BRA C,Fin19Bas    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0    ; 4  W0 à la couleur du Fond si C=0
 Fin19Bas: MOV W0,PORTA   ; 5 on sort la couleur du bit sur PORTA
        NOP			   ; 6
        DEC W9,W9      ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR9Bas; 8 9 non
;11***************************************************************************************************
        MOV [W14++],W4  ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR10Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin110Bas    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0     ; 4  W0 à la couleur du Fond si C=0
 Fin110Bas:MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP			    ; 6
        DEC W9,W9       ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR10Bas; 8 9 non
;12***************************************************************************************************
        MOV [W14++],W4  ; 1 durée= 2 cycles  ' on range le nouvel octet à afficher dans W4
        MOV #7,W9       ; 2 chargement de 8 pour décaler les 8 bits du caractere

AFF_CAR11Bas:MOV _Coulchar2,W0 ; 1 chargement du Blanc dans le registre de sortie W0
        LSR W4,W4       ; 2  rotate left W4
        BRA C,Fin111Bas    ; 3 4   Branchement fin0 si C=1 on affiche le bit
        MOV _Fond2,W0     ; 4  W0 à la couleur du Fond si C=0
 Fin111Bas:MOV W0,PORTA    ; 5 on sort la couleur du bit sur PORTA
        NOP			    ; 6
        DEC W9,W9       ; 7 (a t'on décalé 7 bits ?)
        BRA NZ,AFF_CAR11Bas; 8 9 non
          
        MOV Delta2Bas,W4    ; (total des deltas = 80 + 4 = 84 )
        Repeat W4        ;
        NOP              ;
       

 finlinnBas:
        MOV		_Noir,W0    ; 1018
	    MOV		W0,PORTA	; 1019  on fait le noir
        repeat #17
        NOP
		DEC	  	Count		; 1020  ; nombre de lignes
		BRA 	NZ,Loop6Bas	; 1021 1022  on retrace une ligne
		RETURN				; 1022 1023 1024  (return prend 3 cycles) ;} Fin Linshift
     ;} Fin LinshiftBas

;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Sub Lignes noires">
; Sub LIGNES NOIRES
; ********************    SOUS ROUTINE LIGNES NOIRES  ***********************
;BlkNbs on arrive après 5 cycles ;
;le nombre de lignes générées est dans la variable COUNT
;N lignes moires avec N dans Nlines en entrant
Loop5:  NOP                 ; 1023
        NOP                 ; 1024   Fin trame de 64us
        BCLR     sync,#0    ;1        Début syncro quand on reboucle
        Repeat   #2         ;4
        NOP                 ;5
BlkLns: Repeat 	#68 		; 74 (5+69)   ****entrée de la routine après 5 cycles*****
        NOP 				; 75
   	    BSET	sync,#0	    ; 76		; 4,7us synchro à "1" à n=153
        INC     Nlines      ; 77      numero de ligne
	    repeat	#940		; 1018
		NOP                 ; 1019
		DEC	  	Count		; 1020            ; 15 W0=nombre de lignes noires
		BRA 	NZ,Loop5	; 1021 1022
		RETURN				;} 1022 1023 1024  (return prend 3 cycles)
;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Sub Barres couleur : Colines">
; Sub BARRES DE COULEURS
;{ N lignes couleur avec N dans Nlines en entrant

Loop7:  NOP                 ; 1023
        NOP                 ; 1024   Fin trame de 64us
        BCLR     sync,#0    ;1        Début syncro quand on reboucle
        Repeat   #2         ;4
        NOP                 ;5
Colines:NOP                 ; 6  :; On rentre en 6
        Repeat 	#67 		; 74    ****entrée de la routine après 5 cycles *****
        NOP 				; 75
   	    BSET	sync,#0	    ; 76		; 4,7us synchro à "1" à n=153
        repeat  #121        ; 198 on fait le noir pendant 5us (160 cycles)
        NOP					; 199
        INC     Nlines      ; 200      numero de ligne T=395

        MOV     _Blanc,W0   ; 1
		MOV		W0,PORTA	; 2
		REPEAT  #104  		; 108
		NOP 				; 109

        MOV     _Jaune,W0
		MOV		W0,PORTA	;
		REPEAT  #104  		;
		NOP 				; 109

        MOV     _Cyan,W0
		MOV		W0,PORTA	; 2
		REPEAT  #104  		; 
		NOP                 ; 109
				;
        MOV     _Vert,W0
		MOV		W0,PORTA    ;
		REPEAT  #104 		;
		NOP 				;

        MOV     _Magenta,W0
		MOV		W0,PORTA	;
		REPEAT  #104  		;
		NOP 				;

        MOV     _Rouge,W0
		MOV		W0,PORTA	;
		REPEAT  #104 		;
		NOP 				;

        MOV     _Bleu,W0    ; 1
		MOV		W0,PORTA 	; 2
		REPEAT  #104 		; 108
		NOP 				; 109

        MOV     _Noir,W0        ; 1
		MOV     W0,PORTA  		;2
		REPEAT  #50  			;54
    	NOP                  	;55

    	NOP                 ; 1019
		DEC	  	Count		; 1020
		BRA 	NZ,Loop7	; 1021 1022
		RETURN				;} 1022 1023 1024  (return prend 3 cycles)
;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Sub Barres SMPTE : SMPTEline">
; Sub BARRES DE COULEURS
;{ N lignes couleur avec N dans Nlines en entrant

SMPTELoop7:  NOP                 ; 1023
        NOP                 ; 1024   Fin trame de 64us
        BCLR     sync,#0    ;1        Début syncro quand on reboucle
        Repeat   #2         ;4
        NOP                 ;5
SMPTElines:NOP                 ; 6  :; On rentre en 6
        Repeat 	#67 		; 74    ****entrée de la routine après 5 cycles *****
        NOP 				; 75
   	    BSET	sync,#0	    ; 76		; 4,7us synchro à "1" à n=153
        repeat  #(117)    ; (121) 198 on fait le noir pendant 5us (160 cycles)
        NOP					; 199

        INC     Nlines      ; 200      numero de ligne T=395

        CP0   _Bars       ; 1
        BRA   NZ,Blancbar ; 2 3 ; Si 1 BARRES = Blanc,Ja,Cy,Ve,Mag,Ro,Bleu
        MOV	  _Bleu,W0    ; 3 Si 0 = Bleu,noir,mag,noir,cy,noir,blanc
        BRA   SMPTE1      ; 4 5 couleur SMPTE
Blancbar: MOV _Blanc,W0   ; 4 blanc si _Bars=1   4
        NOP               ; 5

SMPTE1: MOV		W0,PORTA	; 2
		REPEAT  #100  		; 107
		NOP 				; 108

        CP0   _Bars       ; 1
        BRA   NZ,Jaunebar ; 2 3 ; Si 1 BARRES = Blanc,Ja,Cy,Ve,Mag,Ro,Bleu
        MOV	  _Noir,W0    ; 3 Si 0 = Bleu,noir,mag,noir,cy,noir,blanc
        BRA   SMPTE2      ; 4 5 couleur SMPTE
Jaunebar: MOV _Jaune,W0   ; 4 blanc si _Bars=1   4
        NOP               ; 5


SMPTE2: MOV		W0,PORTA	;
		REPEAT  #100  		;
		NOP 				; 108

        CP0   _Bars       ; 1
        BRA   NZ,Cyanbar ; 2 3 ; Si 1 BARRES = Blanc,Ja,Cy,Ve,Mag,Ro,Bleu
        MOV	  _Magenta,W0    ; 3 Si 0 = Bleu,noir,mag,noir,cy,noir,blanc
        BRA   SMPTE3      ; 4 5 couleur SMPTE
Cyanbar: MOV _Cyan,W0   ; 4 blanc si _Bars=1   4
        NOP               ; 5


SMPTE3:	MOV		W0,PORTA	; 2
		REPEAT  #100  		; 107
		NOP                 ; 108

        CP0   _Bars       ; 1
        BRA   NZ,Vertbar ; 2 3 ; Si 1 BARRES = Blanc,Ja,Cy,Ve,Mag,Ro,Bleu
        MOV	  _Noir,W0    ; 3 Si 0 = Bleu,noir,mag,noir,cy,noir,blanc
        BRA   SMPTE4      ; 4 5 couleur SMPTE
Vertbar: MOV _Vert,W0   ; 4 blanc si _Bars=1   4
        NOP               ; 5
				;
SMPTE4:	MOV		W0,PORTA    ;
		REPEAT  #100 		;
		NOP 				;

        CP0   _Bars       ; 1
        BRA   NZ,Magbar ; 2 3 ; Si 1 BARRES = Blanc,Ja,Cy,Ve,Mag,Ro,Bleu
        MOV	  _Cyan,W0    ; 3 Si 0 = Bleu,noir,mag,noir,cy,noir,blanc
        BRA   SMPTE5      ; 4 5 couleur SMPTE
Magbar: MOV _Magenta,W0   ; 4 blanc si _Bars=1   4
        NOP               ; 5


SMPTE5:	MOV		W0,PORTA	;
		REPEAT  #100  		;
		NOP 				;

        CP0   _Bars       ; 1
        BRA   NZ,Rougebar ; 2 3 ; Si 1 BARRES = Blanc,Ja,Cy,Ve,Mag,Ro,Bleu
        MOV	  _Noir,W0    ; 3 Si 0 = Bleu,noir,mag,noir,cy,noir,blanc
        BRA   SMPTE6      ; 4 5 couleur SMPTE
Rougebar: MOV _Rouge,W0   ; 4 blanc si _Bars=1   4
        NOP               ; 5


SMPTE6:	MOV		W0,PORTA	;
		REPEAT  #100 		;
		NOP 				;

        CP0   _Bars       ; 1
        BRA   NZ,Bleubar ; 2 3 ; Si 1 BARRES = Blanc,Ja,Cy,Ve,Mag,Ro,Bleu
        MOV	  _Blanc,W0    ; 3 Si 0 = Bleu,noir,mag,noir,cy,noir,blanc
        BRA   SMPTE7      ; 4 5 couleur SMPTE
Bleubar: MOV _Bleu,W0   ; 4 blanc si _Bars=1   4
        NOP               ; 5


SMPTE7:	MOV		W0,PORTA 	; 2
		REPEAT  #104 		; 107
		NOP 				; 108

		MOV		_Noir,W0 ;1 Noir
		MOV     W0,PORTA  		;2
		REPEAT  #50 			;61
    	NOP                  	;62

    	NOP                 ; 1019
		DEC	  	Count		; 1020
		BRA 	NZ,SMPTELoop7	; 1021 1022
		RETURN				;} 1022 1023 1024  (return prend 3 cycles)
;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Sub Prepa_TextHaut">
Prepa_TextHaut:

    	BSET sync,#0  ; 76

		MOV  #tbloffset (CharGen), W6 ; Adresse du Ptr de la table de caractères
		MOV  #_RamStringHaut,W12 ; (chargement du pointeur sur RamString du programme en C)

		MOV  #TVideo, W14     ;  adresse table RAM des bits à écrire sur l'écran  ; aff
   		MOV  #TAscii, W13     ;  adresse table RAM des caracteres ASCII du message ecran de la trame en cours

 		CP0  Flag    ; 1
       	BRA  LE,Flag1; 2 3         PB NOMBRE INSTRUCTIONS
       	INC  _Shift 	; 3
       	CLR  Flag  	; 4 RAZ du flag d'incrementation du shift
       	CLR  Trame 	; 5 RAZ du décalage fin avec le shift pour synchro dr l'affichage
       	BRA  Flag2 	; 6 7
Flag1: 	NOP 		; 4
       	NOP 		; 5
       	NOP 		; 6
       	NOP 		; 7
Flag2: 	NOP 		; 8

    	MOV      W12,W11  ;  W12,W11  ;  W12 calculé avant appel , adresse du début message dans W11 Sh
    	MOV      _Shift,W4 ;  on charge la valeur du scroll horizontal (_Shift) dans W4
        MUL.UU   W4,#2,W4
    	ADD      W4,W11,W11; 83 addition (valeur du scroll horizontal + adresse du msg) dans W11 = pointeur sur le début
              ; des ce qu'il y a à afficher

;11 x 4 =44


    MOV      [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

    MOV      [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

    MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

  	MOV 	 [W11++],W7
   	SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	MOV 	 [W11++],W7
    CP.B      W7,#0    ; 150 recherche du 0 de fin de message
    BRA       NZ,Suite12 ; 151 152
    CLR       _Shift    ; 152     ; on RAZ _Shift si fin de message haut
    ;CLR Trame

Suite12: repeat #13
    NOP

    ;Preparation
    CLR	    W2		    ; 2  W2=0
    MOV     #4,W0       ; 3 (on repete 4 fois la meme ligne
    MOv		W0, Lineloc ; 4 ; Chargement de 4 dans Lineloc = nombre de répétition des lignes video = 4
    MOV     #28,W0      ; 5 nombre de lignes video pour le text = 28 (4 x 7)
    MOV 	W0,Count    ; 6

    repeat #866     ; 1020
    NOP             ; 1021
    return          ;} 1022 1023 1024   1 (la ligne fait 1 octet de moins ??????)

;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Sub Prepa_TexteBas">
Prepa_TextBas:

    	BSET  	sync,#0  ; 76

		MOV		#tbloffset (CharGen), W6 ; Adresse du Ptr de la table de caractères dans W6
		MOV		#_RamStringBas,W12 ; (chargement du pointeur de RamStringBas du programme en C)

		MOV      #TVideo2, W14     ; adresse table RAM des bits à écrire sur l'écran  ; aff
   		MOV      #TAscii2, W13     ; 80  adresse table RAM des caracteres du message ecran de la trame en cours

 		CP0  FlagBas    ; 1
       	BRA  LE,Flag11; 2 3         PB NOMBRE INSTRUCTIONS
       	INC  _ShiftBas 	; 3
       	CLR  FlagBas  	; 4 RAZ du flag d'incrementation du shift
       	CLR  Trame 	; 5 RAZ du décalage fin avec le shift pour synchro de l'affichage
       	BRA  Flag22 	; 6 7
Flag11: NOP 		; 4
       	NOP 		; 5
       	NOP 		; 6
       	NOP 		; 7
Flag22: NOP 		; 8

    	MOV      W12,W11  ;  W12,W11  ;  W12 calculé avant appel , adresse du début message dans W11 Sh
    	MOV      _ShiftBas,W4 ;  on charge la valeur du scroll horizontal (_ShiftBas) dans W4
        MUL.UU   W4,#2,W4
    	ADD      W4,W11,W11; 83 addition (valeur du scroll horizontal + adresse du msg) dans W11 = pointeur sur le début
              ; de ce qu'il y a à afficher

;11 x 4 =44

	;TBLRDL.B [W11++],W7   ; 2 cycles lecture à l'adresse du caractere à afficher du message  et on le met dans W7
    MOV      [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	;TBLRDL.B [W11++],W7   ; lecture à l'adresse du caractere à afficher du message  et on le met dans W7
    MOV      [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

    ;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
    MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

    ;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
  	MOV 	 [W11++],W7
   	SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

    ;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

	;TBLRDL.B [W11++],W7   ; lecture de l'adresse du caractere à afficher du message  et on le met dans W7
 	MOV 	 [W11++],W7
    SL       W7,#3,W4    ; W4      ; multiplication par 8 pour recuperer l'adresse vraie dans la table en ROM
    ADD      W4,W6,[W13++]    ; ok on lit les bytes en ajoutant adresse du pointeur de debut de table(W6 = tableoffst (Chargen))

    ;TBLRDL.B [W11++],W7; +2 148 149
	MOV 	 [W11++],W7
    CP.B      W7,#0    ; 150 recherche du 0 de fin de message
    BRA       NZ,Suite22 ; 151 152
    CLR       _ShiftBas    ; 152     ; on RAZ ShiftBes si fin de message
   ;CLR Trame

Suite22: repeat #13
    NOP

    ;Preparation
    CLR	    W2		    ; 2  W2=0
    MOV     #4,W0       ; 3 (on repete 4 fois la meme ligne
    MOv		W0, Lineloc ; 4 ; Chargement de 4 dans Lineloc = nombre de répétition des lignes video = 4
    MOV     #28,W0      ; 5 nombre de lignes video pour le text = 28 (4 x 7)
    MOV 	W0,Count    ; 6

    repeat #866     ; 1020
    NOP             ; 1021
    return          ;} 1022 1023 1024   1 (la ligne fait 1 octet de moins ??????)
;</editor-fold>

;<editor-fold defaultstate="collapsed" desc="Table caractères">
;Caracteres sont accédés à la location AsciiChar#*8+LineNo avec LineNo dans 0-7
CharGen:
;{
    .BYTE  0x5A, 0x7E, 0x5A, 0x18, 0x18, 0x5A, 0x7E, 0x5A  ;Char  0
    .BYTE  0x42, 0x7E, 0x5A, 0x18, 0x18, 0x5A, 0x7E, 0x42  ;Char  1
    .BYTE  0x81, 0x42, 0x24, 0x24, 0x24, 0x24, 0x42, 0x81  ;Char  2
    .BYTE  0x81, 0x42, 0x3C, 0x00, 0x00, 0x3C, 0x42, 0x81  ;Char  3
    .BYTE  0x00, 0x00, 0x00, 0x24, 0x99, 0x5A, 0xFF, 0x00  ;Char  4
    .BYTE  0x80, 0x00, 0x00, 0xC0, 0xC0, 0xFC, 0xFE, 0xFC  ;Char  5
    .BYTE  0x01, 0x01, 0x01, 0x03, 0xC7, 0xFF, 0xFF, 0x7F  ;Char  6
    .BYTE  0x80, 0x80, 0x80, 0xC0, 0xE3, 0xFF, 0xFF, 0xFE  ;Char  7
    .BYTE  0x01, 0x00, 0x00, 0x03, 0x03, 0x3F, 0x7F, 0x3F  ;Char  8
    .BYTE  0x00, 0x00, 0xFE, 0x20, 0x20, 0xF8, 0xE0, 0x00  ;Char  9
    .BYTE  0x00, 0x00, 0x18, 0xFE, 0x07, 0x1F, 0x1F, 0x00  ;Char  10
    .BYTE  0x00, 0x00, 0x18, 0x7F, 0xE0, 0xF8, 0xF8, 0x00  ;Char  11
    .BYTE  0x00, 0x00, 0x7F, 0x04, 0x04, 0x1F, 0x07, 0x00  ;Char  12
    .BYTE  0x18, 0x3C, 0x7E, 0xFE, 0x7E, 0x3C, 0x10, 0x10  ;Char  13
    .BYTE  0x00, 0x00, 0x18, 0x3C, 0x7E, 0x7E, 0x6A, 0x7A  ;Char  14
    .BYTE  0x18, 0xBC, 0xFE, 0xFF, 0xB5, 0xFF, 0xB5, 0xFD  ;Char  15
    .BYTE  0x18, 0x3C, 0x5A, 0x18, 0x18, 0x18, 0x18, 0x3C  ;Char  16
    .BYTE  0xF0, 0xE0, 0xF0, 0xB8, 0x1D, 0x0E, 0x04, 0x08  ;Char  17
    .BYTE  0x00, 0x20, 0x41, 0xFF, 0xFF, 0x41, 0x20, 0x00  ;Char  18
    .BYTE  0x08, 0x04, 0x0E, 0x1D, 0xB8, 0xF0, 0xE0, 0xF0  ;Char  19
    .BYTE  0x3C, 0x18, 0x18, 0x18, 0x18, 0x5A, 0x3C, 0x18  ;Char  20
    .BYTE  0x10, 0x20, 0x70, 0xB8, 0x1D, 0x0F, 0x07, 0x0F  ;Char  21
    .BYTE  0x00, 0x04, 0x82, 0xFF, 0xFF, 0x82, 0x04, 0x00  ;Char  22
    .BYTE  0x0F, 0x07, 0x0F, 0x1D, 0xB8, 0x70, 0x20, 0x10  ;Char  23
    .BYTE  0x00, 0x7C, 0x52, 0x7C, 0x50, 0x50, 0x50, 0x00  ;Char  24
    .BYTE  0x00, 0x00, 0x00, 0x40, 0x7E, 0x02, 0x00, 0x00  ;Char  25
    .BYTE  0x00, 0x1C, 0x14, 0x14, 0x3E, 0x14, 0x1C, 0x00  ;Char  26
    .BYTE  0x00, 0x1C, 0x14, 0x14, 0x14, 0x14, 0x1C, 0x00  ;Char  27
    .BYTE  0x00, 0x7E, 0x40, 0x48, 0x4C, 0x4E, 0x0C, 0x08  ;Char  28
    .BYTE  0x18, 0x24, 0x42, 0x81, 0x18, 0x24, 0x42, 0x81  ;Char  29
    .BYTE  0x00, 0x7E, 0x42, 0x24, 0x18, 0x18, 0x18, 0x18  ;Char  30
    .BYTE  0x81, 0x42, 0x24, 0x18, 0x81, 0x42, 0x24, 0x18  ;Char  31
    .BYTE  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  ;Char  32
    .BYTE  0x08, 0x08, 0x08, 0x08, 0x08, 0x00, 0x08, 0x00  ;Char  33 !
    .BYTE  0x14, 0x14, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00  ;Char  34 "
    .BYTE  0x14, 0x14, 0x3E, 0x14, 0x3E, 0x14, 0x14, 0x00  ;Char  35 #
    .BYTE  0x08, 0x3C, 0x0A, 0x1C, 0x28, 0x1E, 0x08, 0x00  ;Char  36 $
    .BYTE  0x06, 0x26, 0x10, 0x08, 0x04, 0x32, 0x30, 0x00  ;Char  37 %
    .BYTE  0x04, 0x0A, 0x0A, 0x04, 0x2A, 0x12, 0x2C, 0x00  ;Char  38 &
    .BYTE  0x08, 0x08, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00  ;Char  39 '
    .BYTE  0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08, 0x00  ;Char  40 (
    .BYTE  0x08, 0x10, 0x20, 0x20, 0x20, 0x10, 0x08, 0x00  ;Char  41 )
    .BYTE  0x08, 0x2A, 0x1C, 0x08, 0x1C, 0x2A, 0x08, 0x00  ;Char  42 *
    .BYTE  0x00, 0x08, 0x08, 0x3E, 0x08, 0x08, 0x00, 0x00  ;Char  43 +
    .BYTE  0x00, 0x00, 0x00, 0x00, 0x08, 0x08, 0x04, 0x00  ;Char  44 ,
    .BYTE  0x00, 0x00, 0x00, 0x3E, 0x00, 0x00, 0x00, 0x00  ;Char  45 -
    .BYTE  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00  ;Char  46 .
    .BYTE  0x00, 0x20, 0x10, 0x08, 0x04, 0x02, 0x00, 0x00  ;Char  47 /
    .BYTE  0x1C, 0x22, 0x32, 0x2A, 0x26, 0x22, 0x1C, 0x00  ;Char  48 0
    .BYTE  0x08, 0x0C, 0x08, 0x08, 0x08, 0x08, 0x1C, 0x00  ;Char  49 1
    .BYTE  0x1C, 0x22, 0x20, 0x18, 0x04, 0x02, 0x3E, 0x00  ;Char  50 2
    .BYTE  0x3E, 0x20, 0x10, 0x18, 0x20, 0x22, 0x1C, 0x00  ;Char  51 3
    .BYTE  0x10, 0x18, 0x14, 0x12, 0x3E, 0x10, 0x10, 0x00  ;Char  52 4
    .BYTE  0x3E, 0x02, 0x1E, 0x20, 0x20, 0x22, 0x1C, 0x00  ;Char  53 5
    .BYTE  0x38, 0x04, 0x02, 0x1E, 0x22, 0x22, 0x1C, 0x00  ;Char  54 6
    .BYTE  0x3E, 0x20, 0x10, 0x08, 0x04, 0x04, 0x04, 0x00  ;Char  55 7
    .BYTE  0x1C, 0x22, 0x22, 0x1C, 0x22, 0x22, 0x1C, 0x00  ;Char  56 8
    .BYTE  0x1C, 0x22, 0x22, 0x3C, 0x20, 0x10, 0x0E, 0x00  ;Char  57 9
    .BYTE  0x00, 0x00, 0x08, 0x00, 0x08, 0x00, 0x00, 0x00  ;Char  58 :
    .BYTE  0x00, 0x00, 0x08, 0x00, 0x08, 0x08, 0x04, 0x00  ;Char  59 ;
    .BYTE  0x10, 0x08, 0x04, 0x02, 0x04, 0x08, 0x10, 0x00  ;Char  60 <
    .BYTE  0x00, 0x00, 0x3E, 0x00, 0x3E, 0x00, 0x00, 0x00  ;Char  61 =
    .BYTE  0x04, 0x08, 0x10, 0x20, 0x10, 0x08, 0x04, 0x00  ;Char  62 >
    .BYTE  0x1C, 0x22, 0x10, 0x08, 0x08, 0x00, 0x08, 0x00  ;Char  63 ?
    .BYTE  0x1C, 0x22, 0x2A, 0x3A, 0x1A, 0x02, 0x3C, 0x00  ;Char  64 @
    .BYTE  0x08, 0x14, 0x22, 0x22, 0x3E, 0x22, 0x22, 0x00  ;Char  65 A
    .BYTE  0x1E, 0x22, 0x22, 0x1E, 0x22, 0x22, 0x1E, 0x00  ;Char  66 B
    .BYTE  0x1C, 0x22, 0x02, 0x02, 0x02, 0x22, 0x1C, 0x00  ;Char  67 C
    .BYTE  0x1E, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1E, 0x00  ;Char  68 D
    .BYTE  0x3E, 0x02, 0x02, 0x1E, 0x02, 0x02, 0x3E, 0x00  ;Char  69 E
    .BYTE  0x3E, 0x02, 0x02, 0x1E, 0x02, 0x02, 0x02, 0x00  ;Char  70 F
    .BYTE  0x3C, 0x02, 0x02, 0x02, 0x32, 0x22, 0x3C, 0x00  ;Char  71 G
    .BYTE  0x22, 0x22, 0x22, 0x3E, 0x22, 0x22, 0x22, 0x00  ;Char  72 H
    .BYTE  0x1C, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1C, 0x00  ;Char  73 I
    .BYTE  0x20, 0x20, 0x20, 0x20, 0x20, 0x22, 0x1C, 0x00  ;Char  74 J
    .BYTE  0x22, 0x12, 0x0A, 0x06, 0x0A, 0x12, 0x22, 0x00  ;Char  75 K
    .BYTE  0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x3E, 0x00  ;Char  76 L
    .BYTE  0x22, 0x36, 0x2A, 0x2A, 0x22, 0x22, 0x22, 0x00  ;Char  77 M
    .BYTE  0x22, 0x22, 0x26, 0x2A, 0x32, 0x22, 0x22, 0x00  ;Char  78 N
    .BYTE  0x1C, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1C, 0x00  ;Char  79 O
    .BYTE  0x1E, 0x22, 0x22, 0x1E, 0x02, 0x02, 0x02, 0x00  ;Char  80 P
    .BYTE  0x1C, 0x22, 0x22, 0x22, 0x2A, 0x12, 0x2C, 0x00  ;Char  81 Q
    .BYTE  0x1E, 0x22, 0x22, 0x1E, 0x0A, 0x12, 0x22, 0x00  ;Char  82 R
    .BYTE  0x1C, 0x22, 0x02, 0x1C, 0x20, 0x22, 0x1C, 0x00  ;Char  83 S
    .BYTE  0x3E, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x00  ;Char  84 T
    .BYTE  0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1C, 0x00  ;Char  85 U
    .BYTE  0x22, 0x22, 0x22, 0x22, 0x22, 0x14, 0x08, 0x00  ;Char  86 V
    .BYTE  0x22, 0x22, 0x22, 0x2A, 0x2A, 0x36, 0x22, 0x00  ;Char  87 W
    .BYTE  0x22, 0x22, 0x14, 0x08, 0x14, 0x22, 0x22, 0x00  ;Char  88 X
    .BYTE  0x22, 0x22, 0x14, 0x08, 0x08, 0x08, 0x08, 0x00  ;Char  89 Y
    .BYTE  0x3E, 0x20, 0x10, 0x08, 0x04, 0x02, 0x3E, 0x00  ;Char  90 Z
    .BYTE  0x3E, 0x06, 0x06, 0x06, 0x06, 0x06, 0x3E, 0x00  ;Char  91 [
    .BYTE  0x00, 0x02, 0x04, 0x08, 0x10, 0x20, 0x00, 0x00  ;Char  92 \
    .BYTE  0x3E, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3E, 0x00  ;Char  93 ]
    .BYTE  0x00, 0x00, 0x08, 0x14, 0x22, 0x00, 0x00, 0x00  ;Char  94 ^
    .BYTE  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3E, 0x00  ;Char  95 _
    .BYTE  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  ;Char  96 `
    .BYTE  0x00, 0x00, 0x1C, 0x20, 0x3C, 0x22, 0x3C, 0x00  ;Char  97 a
    .BYTE  0x02, 0x02, 0x1A, 0x26, 0x22, 0x22, 0x1E, 0x00  ;Char  98 b
    .BYTE  0x00, 0x00, 0x1C, 0x02, 0x02, 0x22, 0x1C, 0x00  ;Char  99 c
    .BYTE  0x20, 0x20, 0x2C, 0x32, 0x22, 0x22, 0x3C, 0x00  ;Char  100 d
    .BYTE  0x00, 0x00, 0x1C, 0x22, 0x3E, 0x02, 0x1C, 0x00  ;Char  101 e
    .BYTE  0x18, 0x24, 0x04, 0x0E, 0x04, 0x04, 0x04, 0x00  ;Char  102 f
    .BYTE  0x00, 0x3C, 0x22, 0x22, 0x3C, 0x20, 0x1C, 0x00  ;Char  103 g
    .BYTE  0x02, 0x02, 0x1A, 0x26, 0x22, 0x22, 0x22, 0x00  ;Char  104 h
    .BYTE  0x00, 0x08, 0x00, 0x0C, 0x08, 0x08, 0x1C, 0x00  ;Char  105 i
    .BYTE  0x10, 0x00, 0x18, 0x10, 0x10, 0x12, 0x0C, 0x00  ;Char  106 j
    .BYTE  0x02, 0x02, 0x12, 0x0A, 0x06, 0x0A, 0x12, 0x00  ;Char  107 k
    .BYTE  0x0C, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1C, 0x00  ;Char  108 l
    .BYTE  0x00, 0x00, 0x16, 0x2A, 0x2A, 0x2A, 0x2A, 0x00  ;Char  109 m
    .BYTE  0x00, 0x00, 0x1A, 0x26, 0x22, 0x22, 0x22, 0x00  ;Char  110 n
    .BYTE  0x00, 0x00, 0x1C, 0x22, 0x22, 0x22, 0x1C, 0x00  ;Char  111 o
    .BYTE  0x00, 0x00, 0x1E, 0x22, 0x1E, 0x02, 0x02, 0x00  ;Char  112 p
    .BYTE  0x00, 0x00, 0x2C, 0x32, 0x3C, 0x20, 0x20, 0x00  ;Char  113 q
    .BYTE  0x00, 0x00, 0x1A, 0x26, 0x02, 0x02, 0x02, 0x00  ;Char  114 r
    .BYTE  0x00, 0x00, 0x1C, 0x02, 0x1C, 0x20, 0x1E, 0x00  ;Char  115 s
    .BYTE  0x04, 0x04, 0x0E, 0x04, 0x04, 0x24, 0x18, 0x00  ;Char  116 t
    .BYTE  0x00, 0x00, 0x22, 0x22, 0x22, 0x32, 0x2C, 0x00  ;Char  117 u
    .BYTE  0x00, 0x00, 0x22, 0x22, 0x22, 0x14, 0x08, 0x00  ;Char  118 v
    .BYTE  0x00, 0x00, 0x22, 0x22, 0x22, 0x2A, 0x14, 0x00  ;Char  119 w
    .BYTE  0x00, 0x00, 0x22, 0x14, 0x08, 0x14, 0x22, 0x00  ;Char  120 x
    .BYTE  0x00, 0x00, 0x22, 0x22, 0x3C, 0x20, 0x1C, 0x00  ;Char  121 y
    .BYTE  0x00, 0x00, 0x3E, 0x10, 0x08, 0x04, 0x3E, 0x00  ;Char  122 z
    .BYTE  0x30, 0x08, 0x08, 0x04, 0x08, 0x08, 0x30, 0x00  ;Char  123 {
    .BYTE  0x06, 0x08, 0x08, 0x10, 0x08, 0x08, 0x06, 0x00  ;Char  124 |
    .BYTE  0x08, 0x08, 0x08, 0x00, 0x08, 0x08, 0x08, 0x00  ;Char  125 }
    .BYTE  0x00, 0x08, 0x00, 0x3E, 0x00, 0x08, 0x00, 0x00  ;Char  126 ~
    .BYTE  0x00, 0x00, 0x20, 0x1C, 0x02, 0x00, 0x00, 0x00  ;Char  127 ;}
    ; Fin Table Chargen
;</editor-fold>

;Message1: 
/*	.asciz	"    F1CJN                " ; Fin de chaîne  "\r"  =0xOD en Hexa , 13 espaces AV et AR */
;Message2:   
/*	.asciz	"           145.750 MHz VIA RELAIS F5ZDW            "*/
;Message3:   ; text en scrolling
/*	.asciz	"\r\n  PICDREAM II par alain.fort.f1cjn@sfr.fr\r\n" ;  "\R"=CR  "\n"=LF  */


.end      ;fin du code programme dans ce fichier


