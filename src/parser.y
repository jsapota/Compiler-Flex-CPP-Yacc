%{
#include <common.h>
#include <fstream>
#include <vector>
#include <cln/integer.h>
int yylex(void);
void yyerror(const char *msg);
//zmienilem zakres addresu
uint64_t address = 0;
static int label = 0;
extern FILE *yyin;
uint64_t asmline = 0;
std :: vector <std :: string> code;
inline void pomp(int numRegister, uint64_t val);
/* 0 iff ikty bit w n = 0, else 1 */
#define GET_BIT(n , k)      (((n) & (1ull << k)) >> k )
#define GET_BIGBIT(n, k)    ((cln :: oddp(n >> k)))
#define MAX(a,b) ((a) > (b) ? (a) : (b))
inline void writeAsm(std :: string const &str);
%}

/* we need own struct so define it before use in union */
%code requires
{
    #include <string.h>
    #include <map>
    #include <cln/integer.h>

    typedef struct yytoken
    {
        char *str;
        int line;
    }yytoken;

    typedef struct Variable
    {

        std :: string name;

        int reg;
        //zmienilem zakres addresu
        uint64_t addr;
        //zmienilem zakres tablicy
        uint64_t len;
        //zakres wartosci
        uint64_t val;

        bool isNum;
        bool upToDate;
        bool array;
        bool init;
        bool iter;


        uint64_t offset; /* t[1000] := a + b   offset = 1000 */
        struct Variable *varOffset; /*  t[b] := a + c  varOffset = ptr --> b*/

    }Variable;
    void inline pomp_addr(int numRegister, Variable const &var);
    void inline pompBigValue(int numRegister, cln :: cl_I value);
    void inline variable_copy(Variable &dst, Variable const &src);
    void variable_load(Variable const &var, int numRegister);
    static std :: map<std :: string, Variable> variables;
}

/* override yylval */
%union
{
    yytoken token;
    Variable *var;
}


%token	ASSIGN
%token	NE LE GE
%token	VAR _BEGIN END
%token	READ WRITE SKIP
%token	FOR FROM TO DOWNTO ENDFOR
%token	WHILE DO ENDWHILE
%token	IF THEN ELSE ENDIF
%token	VARIABLE NUM
%token	ERROR

%type <token> VARIABLE vdeclar '[' NUM ']'
%type <var> identifier value

%%


program:
	%empty
	| VAR vdeclar _BEGIN commands END
    {
        writeAsm("HALT\n");
    }
;

vdeclar:
	%empty
	| vdeclar VARIABLE
    {
        /*
            reg = -1;
            addr = -1;
            len = 0;

            array = false;
            init = false;
            upToDate = true;
            iter = false;

            val = 0;
        */
        auto it = variables.find(std :: string($2.str));
        if (it != variables.end())
        {
            std :: cerr << "REDECLARED\t" << $2.str << std :: endl;
            exit(1);
        }
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = address++;
        var.len = 0;
        var.isNum = false;
        var.array = false;
        var.init = false;
        var.upToDate = true;
        var.iter = false;
        var.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );
    }
	| vdeclar VARIABLE '[' NUM ']'
    {
        /*
            reg = -1;
            addr = -1;
            len = NUM;

            array = true;
            init = false;
            upToDate = true;
            iter = false;
        */
        auto it = variables.find(std :: string($2.str));
        if (it != variables.end())
        {
            std :: cerr << "REDECLARED\t" << $2.str << std :: endl;
            exit(1);
        }
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = address;
        var.isNum = false;
        var.len = strtoll ($4.str, &$4.str, 10);
        address += var.len;
        if(var.len == 0)
        {
            std :: cerr << "SIZE OF ARRAY CANT BE 0\t" << $2.str << std :: endl;
            exit(1);
        }
        var.array = true;
        var.init = false;
        var.upToDate = true;
        var.iter = false;
        var.iter = false;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );
    }
;

commands:
	command
	| commands command
;

command:
	identifier ASSIGN expr ';'
    {
        /* Konwencja mowi ze wynik expr bedzie w R1  */

        /* ustaw R0 na addr identifiera  WIEMY ZE TO VAR */
        pomp_addr(0, *$1); // R0 = addres zmiennej
        writeAsm("STORE 1\n"); //
        variables[$1->name].init = true;
    }
	| IF cond THEN commands ELSE commands ENDIF
	| WHILE cond DO commands ENDWHILE
	| FOR VARIABLE FROM value TO value DO commands ENDFOR
	| FOR VARIABLE FROM value DOWNTO value DO commands ENDFOR
	| READ identifier ';'
    {
        /*
            Scenariusz:

            Ladujemy do R1 wartosc
            ustawiamy R0 na jego address
            zapisujemy wartosc
         */

         writeAsm("GET 1\n");

         pomp_addr(0, *$2);

         writeAsm("STORE 1\n");

         variables[$2->name].init = true;
    }
	| WRITE value ';'
    {
        /*
            Scenariusz:

            1. Wypisujemy zmienna
                ustaw w R0 addres
                wczytaj do R1
                wypisz R1 na stdout
            2. Stala
                pompuj do R1
                wypisz R1 na stdout
        */

        if(! $2->isNum)
        {
            pomp_addr(0, *$2);
            writeAsm("LOAD 1\n");
            writeAsm("PUT 1\n");
        }
        else
        {
            pomp(1, $2->val);
            writeAsm("PUT 1\n");
        }

    }
	| SKIP ';'
;

expr:
	value
    {
            if($1->isNum) {
                pomp(1,$1->val);
            }
            else
            {
                pomp_addr(0, *$1);
                writeAsm("LOAD 1\n");
            }
    }
	| value '+' value  {
            if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                    exit(1);
                }
            }
            if(!$3->isNum){
                auto it = variables[$3->name];
                if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                    exit(1);
                }
            }
                // stala i stala
            if($1->isNum && $3->isNum){
                /* TODO: Zmiana na BigValue ( czyli cln a = $1->val, b = $3->val, pompBig(2, a + b)) */
                    pomp(1, $1->val + $3->val);
                    cln :: cl_I a = $1->val;
                    cln :: cl_I b = $3->val;
                    //pompBigValue(1,a + b);

            }
            else{
                // zmienna i stala
                if(!$1->isNum && $3->isNum){
                    pomp_addr(0,*$1); //R0 = a.addr;
                    pomp(1,$3->val); // R1 = b;
                    writeAsm("ADD 1\n"); //R1 = memRO + b = a + b
                }
                // stala i zmienna
                if($1->isNum && !$3->isNum){
                    pomp_addr(0,*$3); //R0 = b.addr;
                    pomp(1,$1->val); // R1 = memRO + a = b + a;
                    writeAsm("ADD 1\n"); //R2 = a + b
                }
                // dwie zmienne
                if(!$1->isNum && !$3->isNum){
                    pomp_addr(0,*$1); //R0 = a.addr;
                    writeAsm("LOAD 1\n"); // R1 = a;
                    pomp_addr(0,*$3); // R0 = b.addr;
                    writeAsm("ADD 1\n"); //R2 = a + memR0 = a + b
                }
            }
    }
	| value '-' value  {
            if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                    exit(1);
                }
            }
            if(!$3->isNum){
                auto it = variables[$3->name];
                if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                    exit(1);
                }
            }
            // stala i stala
        if($1->isNum && $3->isNum)
            if($3->val > $1->val)
                writeAsm("ZERO 1\n");
            else
            {
                if($3->val >= $1->val)
                    writeAsm("ZERO 1\n");
                else
                    pomp(1, $1->val - $3->val);
            }
        else{
            // zmienna i stala
            if(!$1->isNum && $3->isNum){
                pomp_addr(0,*$1); //R0 = a.addr;
                writeAsm("LOAD 1\n"); // R2 = a;
                pomp(2,$3->val); // R0 = b;
                pomp(0,address + 1);
                writeAsm("STORE 2\n");
                writeAsm("SUB 1\n"); //R2 = a + b
            }
            // stala i zmienna
            if($1->isNum && !$3->isNum){
                pomp_addr(0,*$3); //R0 = a.addr;
                pomp(1,$1->val); // R0 = b;
                writeAsm("SUB 1\n"); //R2 = a + b
            }
            // dwie stale
            if(!$1->isNum && !$3->isNum){
                pomp_addr(0,*$1); //R0 = a.addr;
                writeAsm("LOAD 1\n"); // R2 = a;
                pomp_addr(0,*$3); // R0 = b.addr;
                writeAsm("SUB 1\n"); //R2 = a + memR0 = a + b
            }
        }
    }
	| value '*' value  { // Wedlug mnie powinno dzialac. To obmyslilem w nocy
        if(!$1->isNum){
        auto it = variables[$1->name];
        if (!it.init)
            {
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
        }
        // Czysty assembler
        if($1->isNum)
            pomp(1,$1->val); //a
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
        }
        if($3->isNum){
            pomp(2,$3->val); //b
            pomp(3,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n");
            writeAsm("LOAD 3\n");
        }

        writeAsm("ZERO 4\n");
        std :: string result;
        int jumpline;
//////////  while a > 1
        jumpline = asmline + 2;
        result = "JODD 3 " + std::to_string(jumpline);
        writeAsm(result+"\n");  // line 1 //  nieparzyste to ET1
        jumpline = asmline + 9;
        result = "JUMP " + std::to_string(jumpline);
        writeAsm(result+"\n");  // line 2 //  parzyste to ET2
//////////  ET1 -  a % 2 = 1
        writeAsm("STORE 1\n");   // line 3
        writeAsm("ADD 4\n");    // line 4
        writeAsm("DEC 2\n");    // line 5
        writeAsm("SHR 2\n");    // line 6
        writeAsm("SHL 1\n");    // line 7
        writeAsm("DEC 3\n");    // line 8
        writeAsm("SHR 3\n");    // line 9
        jumpline = asmline + 4;
        result = "JUMP " + std::to_string(jumpline);
        writeAsm(result+"\n");  // line 10
//////////  koniec ifa w ktorym mamy nieparzysty mnoznik
//////////  ET2 warunek ifa z parzystym mnoznikiem
        writeAsm("SHR 2\n"); // line 11
        writeAsm("SHL 1\n"); // line 12
        writeAsm("SHR 3\n"); // line 13 //  krok while a = a/2
/////////   koniec ifa parzystego
        jumpline = asmline + 4;
        writeAsm("DEC 3\n"); // line 14 // dla a = 1 konczymy petle
        result = "JZERO 3 " + std::to_string(jumpline);
        writeAsm(result+"\n"); // line 15
        writeAsm("INC 3\n"); // line 16
        jumpline = asmline - 16;
        result = "JUMP " + std::to_string(jumpline);
        writeAsm(result+"\n"); // line 17
/////////   koniec while


/////////  ET3 - END Dodaj wszystkie czynniki wolne ktore sumowalismy w ELSE
        writeAsm("STORE 4\n");
        writeAsm("ADD 1\n");
////////   Wynik w R2 - bo nie bylem pewien z konwencja gdzie go wrzucic.

    }
	| value '/' value  {
        if(!$1->isNum){
        auto it = variables[$1->name];
        if (!it.init)
            {
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
        }
        // Czysty assembler
        // Czysty assembler
        if($1->isNum)
            pomp(1,$1->val); //a
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
        }
        if($3->isNum){
            pomp(2,$3->val); //b
            pomp(3,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n");
            writeAsm("LOAD 3\n");
        }

        //  Zaladowane wiec dzielimy












    }
	| value '%' value  {
            if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                    exit(1);
                }
            }
            if(!$3->isNum){
                auto it = variables[$3->name];
                if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                    exit(1);
                }
            }
            // Czysty assembler
            if($1->isNum)
                pomp(1,$1->val); //a
            else{
                pomp_addr(0,*$1);
                writeAsm("LOAD 1\n");
            }
            if($3->isNum){
                pomp(2,$3->val); //b
                pomp(3,$3->val); //b
            }
            else{
                pomp_addr(0,*$3);
                writeAsm("LOAD 2\n");
                writeAsm("LOAD 3\n");
            }

            //  Zaladowane wiec mod















    }
;

    // W R0 lub w R1 bedzie wynik 1 - true, 0 - false
cond:
	value '=' value       {

        // Napomuj R2 = a, R3 = a, R4 = b
        if($1->isNum){
            pomp(2,$1->val); //a
            pomp(3,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 2\n");
            writeAsm("LOAD 3\n");
        }
        if($3->isNum){
            pomp(4,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 4\n"); //b
        }

        //Czy b <= a
        writeAsm("STORE 4\n");     // b -> memR0
        writeAsm("SUB 2\n"); //b   // R2 = a - memR0 = a - b
        std :: cout << "JZERO 2" << " ET" << label++ << std :: endl; // jezeli R2 == 0 to skocz do ET1
        std :: cout << "JUMP ET" << label++ << std :: endl; //  skocz do ET2 - FALSE

        // ET1 - pierwszy warunek spelniony - teraz drugi warunek
        //CZY b - a == 0 ??
        std :: cout << "STORE" << " 2" << std :: endl;// a -> memR0
        std :: cout << "SUB" << " 3" << std :: endl;// R3 = a - memR0 = a - b
        std :: cout << "JZERO 3" << " ET" << label++ << std :: endl; // jezeli R3 == 0 to skocz do ET3 czyli rownosc spelniona
        std :: cout << "JUMP ET" << label-- << std :: endl; //  // ma skoczyc do 2 a nie do 3 wiec label--


        // ET2 - nie spelnione - wrzuc wartosc do R0 - false i skocz do etykiety ET3
        //a > b lub b > a
        std :: cout << "JUMP ET" << label++ << std :: endl;

        //ET3 - END
        std :: cout << "HALT"  << std :: endl;


  }
	| value NE value
    {
        // W R0 lub w R1 bedzie wynik 1 - true, 0 - false
        // Napomuj R2 = a, R3 = a, R4 = b
        if($1->isNum){
            pomp(2,$1->val); //a
            pomp(3,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 2\n");
            writeAsm("LOAD 3\n");
        }
        if($3->isNum){
            pomp(4,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 4\n");
        }

        //Czy b => a
        std :: cout << "STORE" << " 4" << std :: endl;       // b -> memR0
        std :: cout << "SUB" << " 2" << std :: endl;        // R2 = a - memR0 = a - b
        std :: cout << "JZERO 2" << " ET" << label++ << std :: endl; // b > a lub b == a
        label += 2;
        std :: cout << "JUMP ET" << label << std :: endl; //  a-b > 0 to mamy nierownosc wiec skocz do ET3 - TRUE

        // ET1 wiec b >= a
        //CZY a == b?
        std :: cout << "STORE" << " 2" << std :: endl;// a-> memR0
        std :: cout << "SUB" << " 3" << std :: endl;// R3 = b - memR0 = b - a
        std :: cout << "JZERO 3" << " ET" << label--  << std :: endl; // jezeli R3 == 0 to skocz do ET2 bo FALSE
        std :: cout << "JUMP ET" << label++ << std :: endl; //  skaczemy do ET3 - mamy nierownosc

        //ET2
        std :: cout << "JUMP ET" << label << std :: endl;

        //ET3 - END
        std :: cout << "HALT"  << std :: endl;
    }
	| value '<' value
    {
        //R1 = a MEM[R0] = b
        if($1->isNum){
            pomp(1,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
        }
        if($3->isNum){
            pomp(2,$3->val); //b
            pomp(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$3);
        }

        /* TERAZ MAMY W R1 = a MEM[R0] = b */

        // a < b lub a + 1 <= b
        writeAsm("INC 1\n");       // ++a
        writeAsm("SUB 1\n");      //R2 = R2 - memR0 = a + 1 - b = 0

        /* teraz asmline wskazuje na linie JZER1 wiec zeby przeskoczyc next inst robimy + 2 */
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");      //Jezeli R2 == 0 to mamy spelniony warunek

        /* FALSE ETYKIETA */
        std :: cout << "JUMP ET" << label++ << std :: endl;

    }
	| value '>' value
    {
        if($3->isNum){
            pomp(1,$3->val); //a
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 1\n");
        }
        if($1->isNum){
            pomp(2,$1->val); //b
            pomp(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$1);
        }

        /* TERAZ MAMY W R1 = b MEM[R0] = a */

        // b < a lub b + 1 <= a
        writeAsm("INC 1\n");       // ++b
        writeAsm("SUB 1\n");      //R2 = R2 - memR0 = b + 1 - a = 0

        /* teraz asmline wskazuje na linie JZER1 wiec zeby przeskoczyc next inst robimy + 2 */
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");      //Jezeli R2 == 0 to mamy spelniony warunek

        /* FALSE ETYKIETA */
        std :: cout << "JUMP ET" << label++ << std :: endl;
    }
	| value LE value
    {
        //R1 = a MEM[R0] = b
        if($1->isNum){
            pomp(1,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
        }
        if($3->isNum){
            pomp(2,$3->val); //b
            pomp(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$3);
        }

        /* TERAZ MAMY W R1 = a MEM[R0] = b */

        // a < b lub a <= b
        writeAsm("SUB 1\n");      //R2 = R2 - memR0 = a - b = 0

        /* teraz asmline wskazuje na linie JZER1 wiec zeby przeskoczyc next inst robimy + 2 */
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");      //Jezeli R2 == 0 to mamy spelniony warunek

        /* FALSE ETYKIETA */
        std :: cout << "JUMP ET" << label++ << std :: endl;
    }
	| value GE value
    {

        if($3->isNum){
            pomp(1,$3->val); //a
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 1\n");
        }
        if($1->isNum){
            pomp(2,$1->val); //b
            pomp(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$1);
        }

        /* TERAZ MAMY W R1 = b MEM[R0] = a */

        // b < a lub b  <= a
        writeAsm("SUB 1\n");      //R2 = R2 - memR0 = b - a = 0

        /* teraz asmline wskazuje na linie JZER1 wiec zeby przeskoczyc next inst robimy + 2 */
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");      //Jezeli R2 == 0 to mamy spelniony warunek

        /* FALSE ETYKIETA */
        std :: cout << "JUMP ET" << label++ << std :: endl;

    }
;

value:
	NUM
    {
        $$ = new Variable;
        $$->name = $1.str;
        $$->isNum = true;
        $$->val = atoll($1.str);
    }
	| identifier
    {
        $$ = $1;
    }
;

identifier:
	VARIABLE
    {
        /* czy DECLARED  */
        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }
        /* czy ARRAY  */
        Variable var = variables[std  :: string($1.str)];
        if( var.array){
            std :: cerr << "VARIABLE IS ARRAY" << $1.str << std :: endl;
            exit(1);
        }
        /* czy Propagacja  */
        $$ = new Variable;
        variable_copy(*$$, var);
    }
	| VARIABLE '[' VARIABLE ']'
    {

        /* czy DECLARED  */
        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }
        /* czy ARRAY  */
        Variable var = variables[std  :: string($1.str)];
        if( !var.array){
            std :: cerr << "VARIABLE ISNT ARRAY" << $1.str << std :: endl;
            exit(1);
        }

        /* czy DECLARED  */
        it = variables.find(std :: string($3.str));
        if (it == variables.end())
        {
            std :: cerr << "NOT DECLARED\t" << $3.str << std :: endl;
            exit(1);
        }

        /* czy NIE ARRAY  */
        var = variables[std  :: string($3.str)];
        if( var.array){
            std :: cerr << "VARIABLE CANT BE ARRAY" << $3.str << std :: endl;
            exit(1);
        }


        var = variables[std  :: string($1.str)];
        Variable var2 = variables[std  :: string($3.str)];


        /* czy Propagacja  */
        Variable *varptr1 = new Variable;
        variable_copy(*varptr1, var);
        Variable *varptr2 = new Variable;
        variable_copy(*varptr2, var2);
        varptr1->varOffset = varptr2;
        $$ = new Variable;
        variable_copy(*$$, *varptr1);
    }
	| VARIABLE '[' NUM ']'
    {
        /* czy DECLARED  */
        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }

        /* czy ARRAY  */
        Variable var = variables[std  :: string($1.str)];
        if( !var.array){
            std :: cerr << "VARIABLE ISNT ARRAY\t" << $1.str << std :: endl;
            exit(1);
        }
            /* czy OUT OF RANGE  */
        if( var.len <= atoll($3.str)){
            std :: cerr << "OUT OF RANGE\t" << $1.str << std :: endl;
            exit(1);
        }

            /* Propagacja  */
        $$ = new Variable;
        variable_copy(*$$, var);
        $$->varOffset = NULL;
        $$->offset = atoll($3.str);

    }
;

%%
void yyerror(const char *msg)
{
    printf("ERROR!!!\t%s\t%s\nLINE\t%d\n",msg,yylval.token.str, yylval.token.line);
    exit(1);
}

inline void variable_copy(Variable &dst, Variable const &src)
{
        dst.name = src.name;
        dst.reg = src.reg;
        dst.addr = src.addr;
        dst.len = src.len;
        dst.isNum = src.isNum;
        dst.upToDate = src.upToDate;
        dst.array = src.array;
        dst.init = src.init;
        dst.iter = src.iter;
        dst.val = src.val;
        dst.offset = src.offset;
        dst.varOffset = src.varOffset;
}

inline void pomp(int numRegister, uint64_t val)
{
    int i;

    writeAsm("ZERO " + std :: to_string(numRegister) + "\n");

    for(i = (sizeof(uint64_t) * 8) - 1; i > 0; --i)
        if(GET_BIT(val , i) )
            break;

    for(; i > 0; --i)
        if( GET_BIT(val , i) )
        {
            writeAsm("INC " + std :: to_string(numRegister) + "\n");
            writeAsm("SHL " + std :: to_string(numRegister) + "\n");
        }
        else
        {
            writeAsm("SHL " + std :: to_string(numRegister) + "\n");
        }

    if(GET_BIT(val, i))
        writeAsm("INC " + std :: to_string(numRegister) + "\n");
}

inline void pomp_addr(int numRegister,Variable const &var){
    if(!var.array)
        pomp(numRegister, var.addr);
    else
        if ( var.varOffset == NULL )
            pomp(numRegister, var.addr + var.offset);
        else{
            pomp(4,var.addr);
            pomp(0,var.varOffset->addr);
            writeAsm("ADD 4 \n");
            writeAsm("COPY 4\n");
        }
}


inline void pompBigValue(int numRegister,cln :: cl_I value){
    cln :: cl_I i;

    writeAsm("ZERO " + std :: to_string(numRegister) + "\n");

    for(i = cln :: integer_length(i); i > 0; --i){
        if(GET_BIGBIT(value , i))
            break;
    }

    for(; i > 0; --i)
        if(GET_BIGBIT(value , i))
        {
            writeAsm("INC " + std :: to_string(numRegister) + "\n");
            writeAsm("SHL " + std :: to_string(numRegister) + "\n");
        }
        else
        {
            writeAsm("SHL " + std :: to_string(numRegister) + "\n");
        }

    if(GET_BIGBIT(value, i))
        writeAsm("INC " + std :: to_string(numRegister) + "\n");
}

inline void writeAsm(std :: string const &str)
{
    //std :: string strNew = "Line" + std :: to_string(asmline) + "-" + str;
    //code.push_back(strNew);
    code.push_back(str);
    ++asmline;
}
/*
inline void writeAsmAndJump(s
        writeAsm("SHR 2\n"); // line 13td :: string co nst &str, )
{

    code.push_back(str);

    ++asmline;
}*/

int compile(const char *infile, const char *outfile)
{
    int ret;
    std :: ofstream outstream;

    yyin = fopen(infile, "r");
    ret = yyparse();
    fclose(yyin);

    outstream.open(outfile);

    for(unsigned int i = 0; i < code.size(); ++i)
        outstream << code[i];

    outstream.close();

    return ret;
}
