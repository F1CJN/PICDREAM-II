/*******************************************************
*                PicDreamII_EEPROM.c
* 
* Ce programme est prévu pour fonctionner avec le programme
* PicDreamII_EEPROM_juin15.s (mire en assembleur)
* 
*
* Auteur: Alain Fort <alain.fort.f1cjn@sfr.fr 
*/
/* Débuté en mars 2008 !!! : */
/* 
Le 4 juin 2015
Visualise les strings StringHaut et StringBas en sortie video
Notice:
En mode scrolling le texte utile doit être précédé et suivi de 12 espaces, ce qui est réalisé par le programme
En mode fixe, la longueur du texte doit être de 12 caracteres,
ce qui est réalisé par le programme
Rappel pour écriture programme:
Les variables communes doivent etre declarées en C ("extern int nom"),
puis en Asm (en ".global _nom" puis "_nom: .space 2")
 *
 * Juin 2015 correction bug N°1 = remise à zero des variables Shift et ShiftBas à partir du C quand on reprogramme une ligne fixe
 * Correction Bug n°2 : <reset>  reset amelioré quand on reset sur un scrolling en cours. Revient maintenant correctement à la présentation d'origine.
*/

/**********************************************************/
/*            Version Information                         */
/**********************************************************/
/* V2 du 4 juin 2015									*/
/* PIC24F16KA101											*/
/* Oscillateur 8 Mhz à quartz avec PLL réglé pour FCY =16000000		*/
// Sortie RS232 9600 sur RB7 en broche 11 du PIC  vers TX interface RS232
// entrée RS232 9600 sur RB2 en broche 6 du PIC   vers RX interface RS232
// Sync  RA6 broche 14
// Rouge RA4 broche 10 
// Vert  RB1 broche 3
// Bleu  RB0 Broche 2 
// chaines de caractères limitées à 75 caractères sur écran
//*********************************************************

#include <p24F16KA101.h>
#include <libpic30.h>
#include <xc.h>
#include <stdio.h> 
#include <stdlib.h>
#include <limits.h>
#include <stddef.h>
#include <string.h>
#include <stdbool.h>
#include <ctype.h>

_FOSC( POSCMOD_XT);  //& POSCFREQ_HS) & FCKSM_CSDCMD )
_FGS(GCP_ON) ;   	  //    Set Code de Protection ON
_FOSCSEL (FNOSC_PRIPLL);   //(FNOSC_PRIPLL)  Oscillateur XT 8 MHz avec PLL
                          //(FNOSC_FRCPLL Oscillateur RC (bruyant) 8MHz avec PLL
_FWDT(FWDTEN_OFF);        //    Watchdog Timer non activé
_FDS( DSWDTEN_OFF & DSBOREN_OFF );
_FPOR(BOREN_BOR0 & PWRTEN_OFF );


//  Couleur     =  0B000R00VB ; R en #4, V en #1, B en #0
const int Blanc =  0B00010011 ;
const int Cyan =   0B00000011 ;
const int Vert =   0B00000010 ;
const int Magenta= 0B00010001 ;
const int Rouge  = 0B00010000 ;
const int Bleu  =  0B00000001 ;
const int Noir  =  0B00000000 ;
const int Jaune =  0B00010010 ;

extern void Mire();
int FixeHaut ;  // texte fixe=1 ou scrolling=0 ligne haute
int FixeBas ;  // texte fixe=1 ou scrolling=0 ligne basse
int Shift ;  // valeur du decalage texte ecran en cours ligne haute
int ShiftBas ;//valeur du decalage texte ecran en cours ligne bas
int Fond1 ;
int Fond2 ;
int Coulchar1 ;
int Coulchar2 ;
int Bars ;
int j;
unsigned int Fond ;
unsigned int Coulchar ;
unsigned int Write;
unsigned int flag;
unsigned int i;
volatile unsigned int cmd ;
unsigned int col ;
unsigned int offset;
char * sptr;

int RamStringHaut[100]; ;  //arrays INT (obligatoire) des 100 max char ascii 8 bits rangés sous forme d'entiers 16 bits
int RamStringBas[100];     // Ce sont ces deux Arrays qui sont sauvegardé en EEPROM avec le "Write"

char VarBuffer[102]="            ";// Buffer pour texte à afficher avec 12 espaces en init
char MessageBuffer[100]; // buffer pour entrée clavier
char ColBuffer[7]="1234567"; // buffer pour couleur

const char StringHaut[]={"            PICDREAM II by F1CJN  alain.fort.f1cjn@sfr.fr            "};
// 12 espaces en début et fin des msg
const char StringBas[]={"PICDREAM II "};  // 12 caracteres
const char CRLF[]={"\r\n"};
const char *separateur = { ">" };

const char space12[]={"            "}; // String de 12 espaces

const char *strs[17]  = {"\r","<t1>","<t2>","<c1>","<c2>","<b1>"
        ,"<b2>","<s1>","<s2>","<f1>","<f2>","<bar>","<smpte>","<w>","yes","<help>","<reset>"};
const char *colors[8] = {"wh","ye","cy","gr","ma","re"
        ,"bl","bk"}; // Texte clavier pour couleurs

int __attribute__ ((space(eedata))) eeData = 0x1234;  // Global variable located in EEPROM
int data ;  // data en retour de la fonction read_eeprom(int addr)

 #define FCY (unsigned long) 16000000

void eeprom_write(int addr, unsigned int data);
void eeprom_read(int addr);

void msg_init(void)
{
    for( j = 0; j<100 ; j++)
    {
    RamStringHaut[j]=(StringHaut[j]);/* Ecrit en array integer POUR AFFICHAGE !!!!*/
    RamStringBas[j] =(StringBas[j]);/* Ecrit en array integer POUR AFFICHAGE !!!!*/
    }

   //                 Init variables C pour mire
FixeHaut = 0 ;     // Scroll Lignes haut fixes si Fixes1=1
FixeBas = 1 ;      //Scroll si 0 */
Fond = Bleu ;
Fond1 = Bleu ;
Fond2 = Bleu ;
Coulchar= Blanc ;
Coulchar1 = Blanc ;
Coulchar2 = Blanc ;
Bars = 0 ; //SMPTE
Write =0 ;
flag=0 ; // RAZ du flag si le text est # de "yes" pour ecriture EEPROM
i=0 ; j=0 ;
eeprom_read(0);
if ( data  == 0xA5A5) //
   {
     eeprom_read(2);Fond1 = data ;
     eeprom_read(4);Fond2 = data ;
     eeprom_read(6);Coulchar1 = data ;
     eeprom_read(8);Coulchar2 = data ;
     eeprom_read(10);FixeHaut = data ;
     eeprom_read(12);FixeBas  = data ;
     eeprom_read(14);Bars = data ;

     for(i=20; i<120; i+=1)
        {
                  eeprom_read(i+i);
                RamStringHaut[i-20]=  data ;
          // printf ("DATA = %x\n", data );
        }
     for(i=120; i<220; i+=1)
        {
                  eeprom_read(i+i);
                RamStringBas[i-120]=data;
           //printf ("DATA = %x\n",data);
        }
   }

}

void eeprom_read(int addr)
 {
     unsigned int offset;
     // Set up a pointer to the EEPROM location to be erased
     TBLPAG = __builtin_tblpage(&eeData); // Initialize EE Data page pointer
     offset = __builtin_tbloffset(&eeData) + (addr); // Initialize lower word of address
     //printf ("TBLPAG = %x\n",TBLPAG);
     //printf ("Offset = %x\n",offset);
     data =__builtin_tblrdl(offset); // Read EEPROM data

     while(NVMCONbits.WR); // Optional: Poll WR bit to wait for
                          // write sequence to complete
 }

void eeprom_write(int addr, unsigned int data)
 {
     unsigned int offset;
     // Set up NVMCON to erase one word of data EEPROM
     NVMCON = 0x4004;
     // Set up a pointer to the EEPROM location to be erased
     TBLPAG = __builtin_tblpage(&eeData); // Initialize EE Data page pointer
     offset = __builtin_tbloffset(&eeData) + (addr); // Initialize lower word of address
    //printf ("TBLPAG = %x\n",TBLPAG);
    //printf ("Offset = %x\n",offset);
     __builtin_tblwtl(offset, data); // Write EEPROM data to write latch
     asm volatile ("disi #5"); // Disable Interrupts For 5 Instructions
     __builtin_write_NVM(); // Issue Unlock Sequence & Start Write Cycle
     while(NVMCONbits.WR); // Optional: Poll WR bit to wait for
                          // write sequence to complete
     TBLPAG =0;
 }

void imprime(s)
char s[];
{
  sptr=s;
  while(*sptr !=0)
  {
       for(i = 0; i < 7000; i++)  // petite tempo entre les caractères
   while(U1STAbits.UTXBF==1); // Wait until TX buf read for new data
   U1TXREG=*sptr;
   sptr++;
  }
  i=0; //On sort proprement
 }

void entete (void)
{
              imprime (CRLF);
              imprime (CRLF);
              imprime ("**   PICDREAM II Video Generator by F1CJN   **\r");
              imprime ("<t1>mytext = text line 1\r");
              imprime ("<t2>mytext = text line 2\r");
              imprime ("<c1>xx = color text line 1\r");
              imprime ("<c2>xx = color text line 2\r");
              imprime ("<b1>xx = color background line 1\r");
              imprime ("<b2>xx = color background line 2\r");
              imprime ("Colors xx : ma=magenta, wh= white, ye=yellow, bk=black\r");
              imprime ("Colors xx : cy=cyan, re= red, gr=green, bl=blue\r");
              imprime ("Exemple : <c1>cy = color text line 1 cyan\r");
              imprime ("<s1> = scroll line 1\r");
              imprime ("<s2> = scroll line 2\r");
              imprime ("<f1> = line 1 fixed \r");
              imprime ("<f2> = line 2 fixed \r");
              imprime ("<bar> = colors bars \r");
              imprime ("<smpte> = smpte bars \r");
              imprime ("<w> = write all in memory, need to confirm with yes \r");
              imprime ("<reset> = reset to original \r");
              imprime ("<help> = this message \r");
              imprime ("    \r");
            //  imprime (CRLF);

}

void enteteraz (void)
{
              imprime (CRLF);
              imprime (CRLF);
              imprime ("**   PICDREAM II Video Generator by F1CJN   **\r");
              imprime ("    \r");
            //  imprime (CRLF);

}

 void __attribute__((interrupt, auto_psv)) _U1RXInterrupt(void) 
{

       if (j > 98) j=99 ; //Limite la taille du test au buffer à 100 carac
       //téres soit  72 caractères utiles (sans la commande de 4 caracteres
       // et sans les 2x 12 espaces)
        {
            MessageBuffer[j] = U1RXREG; //lecture de l'octet du registre RX

           // MessageBuffer[j] = tolower(MessageBuffer[j]);
                    
            if(MessageBuffer[j] == 0x0D) //Test pour la touche CR

               { //-----SI TOUCHE CR
                 char * pch; 
                 int cmd;
                 cmd=0;
                  for(i = 0; i<17 ; i++) //17 On scanne les 17 commandes
                  {
                 pch = strstr ((MessageBuffer),strs[i]); // Scan des commandes
                 if (pch) {cmd=i;} // et recherche des strings des commandes
                  }
            //printf ("cmd = %x\n",cmd);
            switch (cmd)
            {
            case 0 :
            //if(MessageBuffer[0] == 0x0D) //check for CR key
            //imprime("\r");
            //else
            imprime("Command?\r");
            Write = 0 ;

            break;

            case 1 ... 2 : // T1 ou T2 Texte Ligne1 ou 2 
            {
            //On recupere le texte sans la commande <t1> ou <t2> de 4 caracteres
            for(i = 0; i < 70 && MessageBuffer[4 + i] != '\0'; i++)
            MessageBuffer[i] = MessageBuffer[i + 4];
            }
            MessageBuffer[i-1] = '\0'; // place fin des message à i-1 afin
            //de supprimmer le CR à la fin du MessageBuffer
            //imprime(MessageBuffer);
            //imprime("T1 T2\r");
             // MESSAGE FIXE
             if (((FixeHaut==1) && (cmd==1)) || ((FixeBas==1) && (cmd==2))) //Si ligne 1 ou ligne 2 fixes
             {
                 strncpy(VarBuffer,MessageBuffer,11); // Réduit MessageBuffer à 11 characters
                 strcat(VarBuffer,space12);// Ajout de 12 espaces en fin de VarBuffer
                 if (cmd==1){
                     Shift=0;
                 for( j = 0; j<100 ; j++)
                        { RamStringHaut[j]=(VarBuffer[j]);}/* Ecrit en array integer POUR AFFICHAGE !!!!*/
                 //imprime(VarBuffer);
                            }
                 if (cmd==2){
                     ShiftBas=0;
                 for( j = 0; j<100 ; j++)
                        { RamStringBas[j]=(VarBuffer[j]);}/* Ecrit en array integer POUR AFFICHAGE !!!!*/
                 //imprime(VarBuffer);
                            }
                 break;
             }
             //break ;
            // **************   MESSAGE DEROULANT  *******************************
            if (((FixeHaut==0) && (cmd==1)) || ((FixeBas==0) && (cmd==2)))  // Si Ligne1 ou ligne 2 scrolle
             {
                //-----Ajout de 12 espace en début et fin de message(pour scroll)---
            strcat(MessageBuffer,space12);// Ajout de 12 espaces en fin de buffer
            char VarBuffer[102]="            "; // 12 espace en début de Varbuffer
            strcat(VarBuffer,MessageBuffer); //Ajout de 12 espace en début de MessageBuffer
            //imprime(MessageBuffer);
            //imprime(CRLF);

            if (cmd==1) {       // ligne1
                       
                        for( j = 0; j<100 ; j++)
                         { RamStringHaut[j]=(VarBuffer[j]);}/* Ecrit en array integer POUR AFFICHAGE !!!!*/
                         }
            if (cmd==2) {       // Ligne2
                        
                        for( j = 0; j<100 ; j++)
                        { RamStringBas[j]=(VarBuffer[j]);}/* Ecrit en array integer POUR AFFICHAGE !!!!*/
                         }
             }
            break;

            case 3 :  // C1  Couleur ligne1
            case 4 :  // C2  Couleur ligne2
             //  imprime("c1 c2\r");
               strncpy(ColBuffer,MessageBuffer,6); // Reduit MessageBuffer à 7 characters
               for(i = 0; i<8 ; i++) // 8 couleurs
                  {
                 pch = strstr (ColBuffer,colors[i]); // Scan des commandes
                 if (pch) {col=i;}
                  }
                    switch (col)
                    {
                    case 0 : Coulchar = Blanc ; break ;
                    case 1 : Coulchar = Jaune ; break ;
                    case 2 : Coulchar = Cyan ; break;
                    case 3 : Coulchar = Vert ; break ;
                    case 4 : Coulchar = Magenta ; break ;
                    case 5 : Coulchar = Rouge ; break ;
                    case 6 : Coulchar = Bleu ; break ;
                    case 7 : Coulchar = Noir ; break ;
                    default : Coulchar = Blanc ;
                    }
                if (cmd==3) Coulchar1 = Coulchar;
                if (cmd==4) Coulchar2 = Coulchar;
                    cmd=0;
                break;

            case 5 : //B1  Couleur Fond1
            case 6 : //B2  Couleur Fond2
             //    imprime("b1 b2\r");
               strncpy(ColBuffer,MessageBuffer,6); // Reduit MessageBuffer à 7 characters
               // imprime(ColBuffer);
               for(i = 0; i<8 ; i++) // 8 couleurs
                  {
                 pch = strstr (ColBuffer,colors[i]); // Scan des commandes
                 if (pch) (col=i);
                  }
                  switch (col)
                    {
                    case 0 : Fond = Blanc ; break ;
                    case 1 : Fond = Jaune ; break ;
                    case 2 : Fond = Cyan ; break;
                    case 3 : Fond = Vert ; break ;
                    case 4 : Fond = Magenta ; break ;
                    case 5 : Fond = Rouge ; break ;
                    case 6 : Fond = Bleu ; break ; 
                    case 7 : Fond = Noir ; break ;
                    default : Fond = Blanc ;
                    }
                if (cmd==5) Fond1 = Fond;
                if (cmd==6) Fond2 = Fond;
                  cmd=0;
                break;

            case 7 : //S1 Scroll ligne 1
            (FixeHaut = 0 );  // Yes = Scroll Ligne1
            Shift = 1 ;
            break;

            case 8 : //S2 Scroll ligne 2
            (FixeBas = 0 );  // Yes = Scroll Ligne1
            ShiftBas = 1 ;
            break;

            case 9 : //F1 Fixe ligne 1 cmd = 9
            (FixeHaut = 1 );
            Shift=0;
            break;

            case 10 : //F2 Fixe ligne 2 cmd = 10
            (FixeBas = 1 );
            ShiftBas=0;
            break;

            case 11 : // <BAR>
            (Bars = 1);
            break;

            case 12 : // <SMPTE>
            (Bars = 0);
            break;

            case 13 : // <W>
            imprime("WRITE ""yes"" ?\r");
            Write=1;
            break;

            case 14 : // "yes"
            if (Write==1)
            {
               eeprom_write(0,0xA5A5); // MOT pour TEST ECRITURE
               eeprom_write(2,Fond1);
               eeprom_write(4,Fond2);
               eeprom_write(6,Coulchar1);
               eeprom_write(8,Coulchar2);
               eeprom_write(10,FixeHaut);
               eeprom_write(12,FixeBas);
               eeprom_write(14,Bars);               
               for(i=20; i<120; i+=1)
                { eeprom_write(2*i, RamStringHaut[i-20]);}// i-20 pour faire 0-99
               for(i=120; i<220; i+=1)
                { eeprom_write(2*i, RamStringBas[i-120]);}// i-120 pour faire 0 -99
              imprime ("*** WRITE OK ***\r");
              Write = 0 ; cmd=0;
             }
            break;

            case 15 : // "help"
                 i=0;
                 entete();
             break ;

             case 16 : // "reset"
             imprime ("*** RESET *** \r");
             eeprom_write(0,0x1234);
             FixeHaut = 0 ;
             FixeBas = 1 ;
             Shift=1;
             ShiftBas=0;
             msg_init();
             entete();
             TBLPAG=0;
             cmd=0;
             break ;

             default:
             Write = 0 ; cmd=0 ; i=0;
            }  //fin switch
                  //----------------------------------------------------
                 memset(MessageBuffer,0,sizeof(MessageBuffer));// RAZ Buffer
                 memset(VarBuffer,0,sizeof(VarBuffer));// RAZ Buffer
                 j=0; i=0; //par propreté
                 _U1RXIF=0;
                 return; // On sort des "Case"
                 }
            j++; //Pas de CR = increment le pointeur du MessageBuffer
            _U1RXIF=0;
        }
 }

int main(void)
{
  #define FCY (unsigned long) 16000000
  #define BAUDRATE 38400
  #define BRGVAL ((FCY/BAUDRATE)/16)-1 

  CLKDIV=0x0000;              // Divise par 2 = (0 + 2) la F Xtal
  while(OSCCONbits.LOCK!=1);  // Attente lock PLL

 //                 Set up I/O Port
 AD1PCFG=0xFFFF;    //Analog ports as Digital I/O
 TRISA=0;          // Port A avec des sorties
 TRISB=0b0000000000000110;    // Port B avec sorties et RB2 en entrée (UART RX)
 //et RB1 en entrée(pin5)pour le routage du CI
 
U1BRG = BRGVAL;   // BAUD Rate Setting for 9600
U1MODE=0; //clear all U1MODE register
U1STA = 0x0440; //clear all U1STA register and enable Transmit
U1MODEbits.UARTEN = 1; // Enable UART1
U1STAbits.UTXEN = 1; // Enable UART1 TX

IEC0bits.U1RXIE = 1 ;   // RX Interrupt enable
U1STAbits.URXISEL = 0 ; // RX interruption à chaque caractère
IFS0bits.U1RXIF = 0;    // Clear UART1 Received interrupt flag
IPC2bits.U1RXIP = 2 ;   // RX interruption avec niveau de priorité 2

__delay32(10000000);  // delay de 10.000.000 cycles
 
 enteteraz(); // message sur RS232  19200 bauds à la mise sous tension

msg_init(); // Initialisation avec lecture EEPROM;

TBLPAG=0;  // INDISPENSABLE !!!!!
 
Mire ();           /* Envoie la mire */

while(1);

//return(EXIT_SUCCESS);
 };
