%{
#include <common.h>
#include <fstream>
#include <vector>
#include <stack>
#include <map>
#include <variable.h>
#include <asm.h>

int yylex(void);
void yyerror(const char *msg);

/* first free address */
static cln :: cl_I address = 0;
extern FILE *yyin;

/* number of next line in asm code */
uint64_t asmline = 0;

/*  poczatkowe linie petli while i for */
static std :: stack <int64_t> looplines;

static std :: stack <Variable*> iterators;

static std :: map<std :: string, Variable> variables;

/* asm code */
std :: vector <std :: string> code;
/*
    stack with lines from we want to jump HERE
    Usage:
    we want to jzero 2 (20) but now we dont know line number
    Let @line is the current line, ( jzero 2 (20) )
    1. Create string : jzero 2(space)
    2. Call jumpLabel(created string, @line)
    3. When you go to the wanted line, call labelToLine()

    IMPORTANT:

    CURRENT:
    1 cond <--> 1 label

*/
static std :: stack <int64_t> labels;

inline void jumpLabel(std :: string const &str, int64_t line); // jump to false
inline void labelToLine(uint64_t line);

%}

/* we need own struct so define it before use in union */
%code requires
{
    #include<common.h>
    #include<variable.h>

    typedef struct yytoken
    {
        char *str;
        int line;
    }yytoken;

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
	| vdeclar VARIABLE {
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
        var.addr = address;
        address = address + 1;
        var.len = 0;
        var.isNum = false;
        var.array = false;
        var.init = false;
        var.upToDate = true;
        var.iter = false;
        var.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );

    }
	| vdeclar VARIABLE '[' NUM ']'{
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
	identifier ASSIGN expr ';' {
        /* Konwencja mowi ze wynik expr bedzie w R1  */
        /* ustaw R0 na addr identifiera  WIEMY ZE TO VAR */
        auto it = variables[$1->name];
        if (it.iter){
            std :: cerr << "VARIABLE IS ITERATOR\t" << $1->name << std :: endl;
            exit(1);
        }
        pomp_addr(0, *$1); // R0 = addres zmiennej
        writeAsm("STORE 1\n"); //
        variables[$1->name].init = true;
    }
	| ifbeg ifmid ifend
	| whilebeg whileend
	| forbegTO forendTO
	| forbegDOWNTO forendDOWNTO
	| READ identifier ';'{
        /*
            Scenariusz:

            Ladujemy do R1 wartosc
            ustawiamy R0 na jego address
            zapisujemy wartosc
         */
         auto it = variables[$2->name];
         if (it.iter){
             std :: cerr << "VARIABLE IS ITERATOR\t" << $2->name << std :: endl;
             exit(1);
         }
         writeAsm("GET 1\n");
         pomp_addr(0, *$2);
         writeAsm("STORE 1\n");
         variables[$2->name].init = true;

    }
	| WRITE value ';'{
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
            auto it = variables[$2->name];
            if (!it.init){
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $2->name << std :: endl;
                exit(1);
            }
        }
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

ifbeg:
    IF cond THEN{
        /* tutaj i tak skompilowalismy conda wiec nic nie robimy */
    }
ifmid:
    commands ELSE{
        /*
            poprzednia labelka chce skoczyc do else
            + wystawiamy nowa labelke do endif ( czyli omijamy elsa)
        */
        labelToLine(asmline + 1);
        jumpLabel("JUMP ",asmline);
    }
ifend:
    commands ENDIF{
        /* label z else zamieniamy na linie */
            labelToLine(asmline);
    }
prewhile:
    WHILE
    {
        /*  wrzucamy na stos asmline by moc powrocic */
        looplines.push(asmline);
    }
    ;
whilebeg:
    prewhile cond DO{
        /* tu nic juz nie robimy bo mamy linie powrotu i conda zrobionego */
    }
    ;
whileend:
    commands ENDWHILE{
        /* label z conda zamieniamy na linie */
        int64_t line;
        line = looplines.top();
        looplines.pop();

        writeAsm("JUMP " + std :: to_string(line) + "\n");

        labelToLine(asmline);
    }
    ;
forbegTO:
    FOR VARIABLE FROM value TO value DO
    {
        /* deklaracja VAR juz jest wiec zapalamy flage iteratora */
        if(! $4->isNum)
        {
            auto it = variables[$4->name];
            if (!it.init){
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $4->name << std :: endl;
                exit(1);
            }
        }
        if(! $6->isNum)
        {
            auto it = variables[$6->name];
            if (! it.isNum && !it.init){
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $6->name << std :: endl;
                exit(1);
            }
        }

        /* wyluskujemy iterator */
        auto it2 = variables.find(std :: string($2.str));
        if (it2 != variables.end())
        {
            std :: cerr << "REDECLARED ITERATOR\t" << $2.str << std :: endl;
            exit(1);
        }

        /* deklarujemy iterator */
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = address;
        address = address + 1;
        var.len = 0;
        var.isNum = false;
        var.array = false;
        var.init = true; /* zaraz ustawimy ten iterator */
        var.upToDate = true;
        var.iter = true; /* tak to jest iterator */
        var.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );

        /* zapamietaj iterator */
        Variable *iterator = new Variable;
        variable_copy(*iterator, var);

        iterators.push(iterator);

        /* iterator := value1 */
        if(! $4->isNum)
        {
            pomp_addr(0, *$4);
            writeAsm("LOAD 1\n");
        }
        else
            pomp(1, $4->val);

        pomp_addr(0, var);
        writeAsm("STORE 1\n");

        /* zapamietujemy linie */
        int64_t line = asmline;
        looplines.push(line);

        /* COND: it <= value2 */

        /* wczytaj it */
        pomp_addr(0, var);
        writeAsm("LOAD 1\n");

        if($6->isNum){
            pomp(2,$6->val); //b
            pompBigValue(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$6);
        }
        /* TERAZ MAMY W R1 = a MEM[R0] = b */
        // a < b lub a <= b
        writeAsm("SUB 1\n");      //R2 = R2 - memR0 = a - b = 0

        /* teraz asmline wskazuje na linie JZER1 wiec zeby przeskoczyc next inst robimy + 2 */
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");      //Jezeli R2 == 0 to mamy spelniony warunek

        jumpLabel("JUMP ", asmline);

    }
    ;
forendTO:
    commands ENDFOR{

        /* czytamy zapamietany iterator */
        Variable *var;
        var = iterators.top();
        iterators.pop();

        /* INC iterator */
        pomp_addr(0, *var);
        writeAsm("LOAD 1\n");
        writeAsm("INC 1\n");
        writeAsm("STORE 1\n");

        int64_t line;
        line = looplines.top();
        looplines.pop();

        writeAsm("JUMP " + std :: to_string(line) + "\n");

        labelToLine(asmline);

        /* usun iteratora z mapy */
        auto it = variables.find(var->name);
        variables.erase(it);

    };
forbegDOWNTO:
    FOR VARIABLE FROM value DOWNTO value DO{

        /* deklaracja VAR juz jest wiec zapalamy flage iteratora */
        if(! $4->isNum)
        {
            auto it = variables[$4->name];
            if (!it.init){
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $4->name << std :: endl;
                exit(1);
            }
        }
        if(! $6->isNum)
        {
            auto it = variables[$6->name];
            if (! it.isNum && !it.init){
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $6->name << std :: endl;
                exit(1);
            }
        }

        /* wyluskujemy iterator */
        auto it2 = variables.find(std :: string($2.str));
        if (it2 != variables.end())
        {
            std :: cerr << "REDECLARED ITERATOR\t" << $2.str << std :: endl;
            exit(1);
        }

        /* deklarujemy iterator */
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = address;
        address = address + 1;
        var.len = 0;
        var.isNum = false;
        var.array = false;
        var.init = true; /* zaraz ustawimy ten iterator */
        var.upToDate = true;
        var.iter = true; /* tak to jest iterator */
        var.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );

        /* zapamietaj iterator */
        Variable *iterator = new Variable;
        variable_copy(*iterator, var);

        iterators.push(iterator);

        /* iterator := value1 */
        if(! $4->isNum)
        {
            pomp_addr(0, *$4);
            writeAsm("LOAD 1\n");
        }
        else
            pomp(1, $4->val);

        pomp_addr(0, var);
        writeAsm("STORE 1\n");

        /* robimy iterator pomocniczy */
        Variable var2;
        var2.name = std :: string($2.str) + "2";
        var2.reg = -1;
        var2.addr = address;
        address = address + 1;
        var2.len = 0;
        var2.isNum = false;
        var2.array = false;
        var2.init = true; /* zaraz ustawimy ten iterator */
        var2.upToDate = true;
        var2.iter = true; /* tak to jest iterator */
        var2.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var2.name,var2) );

        /* 2 iterator to licznik wykonan ma sie wykonac begin + 1 - end razy */

        /* czytaj begin i incuj */
        if(! $4->isNum)
        {
            pomp_addr(0, *$4);
            writeAsm("LOAD 1\n");
            writeAsm("INC 1\n");
        }
        else
        {
            pomp(1, $4->val);
            writeAsm("INC 1\n");
        }


        /* ustaw R0 na end */
        if(! $6->isNum)
            pomp_addr(0, *$6);
        else
        {
            pomp(2, $6->val);
            pompBigValue(0, address);
            writeAsm("STORE 2\n");
        }

        /* mozemy odejmowac */
        writeAsm("SUB 1\n");

        /* teraz w 1 mamy ilosc wykonan petli zapiszmy do iteratora2 */
        pomp_addr(0, var2);

        writeAsm("STORE 1\n");

        /* KONIEC PRZYGOTOWANIA FORA */
        /* zapamietujemy linie */
        int64_t line = asmline;
        looplines.push(line);

        /* wczytaj drugi iterator */
        pomp_addr(0, var2);
        writeAsm("LOAD 1\n");
        jumpLabel("JZERO 1 ", asmline); /* jesli it == 0 znaczy sie ze wszystko wykonalismy */
    };

forendDOWNTO:
    commands ENDFOR{
        /* czytamy zapamietany iterator */
        Variable *var;
        var = iterators.top();
        iterators.pop();

        /* DEC iterator */
        pomp_addr(0, *var);
        writeAsm("LOAD 1\n");
        writeAsm("DEC 1\n");
        writeAsm("STORE 1\n");

        /* DEC drugiego iteratora */
        auto it = variables[var->name + "2"];
        pomp_addr(0, it);
        writeAsm("LOAD 1\n");
        writeAsm("DEC 1\n");
        writeAsm("STORE 1\n");

        int64_t line;
        line = looplines.top();
        looplines.pop();

        writeAsm("JUMP " + std :: to_string(line) + "\n");

        labelToLine(asmline);

        /* usun iteratora z mapy */
        auto it2 = variables.find(var->name);
        variables.erase(it2);

        auto it3 = variables.find(it.name);
        variables.erase(it3);
}

expr:
	value{
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
                    //pomp(1, $1->val + $3->val);
                    cln :: cl_I a = $1->val;
                    cln :: cl_I b = $3->val;
                    pompBigValue(1,a + b);
                    //std :: cout << a << "+" << b << std :: endl;

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
                pompBigValue(0,address + 1);
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
	| value '*' value  {
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
        jumpline = asmline + 2;
        result = "JODD 3 " + std::to_string(jumpline);
        writeAsm(result+"\n");  // line 1 //  nieparzyste to ET1
        jumpline = asmline + 9;
        result = "JUMP " + std::to_string(jumpline);
        writeAsm(result+"\n");  // line 2 //  parzyste to ET2
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
        writeAsm("SHR 2\n"); // line 11
        writeAsm("SHL 1\n"); // line 12
        writeAsm("SHR 3\n"); // line 13 //  krok while a = a/2
        jumpline = asmline + 4;
        writeAsm("DEC 3\n"); // line 14 // dla a = 1 konczymy petle
        result = "JZERO 3 " + std::to_string(jumpline);
        writeAsm(result+"\n"); // line 15
        writeAsm("INC 3\n"); // line 16
        jumpline = asmline - 16;
        result = "JUMP " + std::to_string(jumpline);
        writeAsm(result+"\n"); // line 17
        writeAsm("STORE 4\n");
        writeAsm("ADD 1\n");
    }
	| value '/' value  {
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
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
        std :: string result;
        int jumpline;
        writeAsm("ZERO 4\n");
        // Czysty assembler
        if($1->isNum){
            pomp(1,$1->val); //a
            pomp(4,$3->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 4\n");
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
        pompBigValue(0,address);
        address = address + 1;
        writeAsm("STORE 2\n");      // b -> memR0
        writeAsm("SUB 1\n");        // R1 = a - memR0 = a - b
        writeAsm("STORE 4\n");      // a -> memR0
        writeAsm("SUB 2\n");           // R2 = b - memR0 = b - a
        // a - b = 0 ==> b >= a
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");    // Jezeli R1 == 0 to mamy spelniony warunek
        // skocz false
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");       // a > b wiec false
        // b - a = 0 ==> a >= b
        writeAsm("JZERO 2 " + std :: to_string(asmline + 2) + "\n");    // Jezeli R2 == 0 to mamy spelniony warunek
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");    // Jezeli R2 == 0 to mamy spelniony warunek
        jumpLabel("JUMP ", asmline);  // false



        // tutaj juz jest true to mamy skoczyc
        pompBigValue(0,address);
        address = address + 1;
        if($1->isNum){
            pomp(1,$1->val); //a
            pomp(4,$3->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 4\n");
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
        pompBigValue(0,address);
        address = address + 1;
        writeAsm("INC 4\n");    // ++a
        writeAsm("STORE 2\n");
        writeAsm("SUB 4\n");    //R1 = R1 - memR0 = a + 1 - b = 0
        jumpLabel("JZERO 4 ", asmline);
        writeAsm("ZERO 4\n");   // line 1
        pompBigValue(0,address);
        address = address + 1;
        writeAsm("ZERO 4\n");
        writeAsm("INC 4\n");
        writeAsm("ZERO 3\n");   // line 1   BKup a
        writeAsm("STORE 1\n");  // line 2   BKup a
        writeAsm("ADD 3\n");    // line 3   BKup a
        writeAsm("STORE 2\n");  // line 4
        writeAsm("SUB 1\n");    // line 5
        jumpline = asmline + 5;
        result = "JZERO 1 " + std::to_string(jumpline);
        writeAsm(result+"\n");  // line 6
        writeAsm("ADD 1\n");    // line 7
        writeAsm("SHL 2\n");    // line 8              // R2 = b * 2
        writeAsm("SHL 4\n");    // line 9              // R4 = nasz przyszly wynik
        jumpline = asmline - 9;
        result = "JUMP " + std::to_string(jumpline);    // dopoki mozna to
        writeAsm(result+"\n");  // line 10
        writeAsm("ZERO 1\n");   // line 11  BKup a
        writeAsm("STORE 3\n");  // line 12  BKup a
        writeAsm("ADD 1\n");    // line 13  BKup a
        writeAsm("SHR 2\n");    // line 14  cofnij SHL na dzelniku
        writeAsm("SHR 4\n");    // line 15  cofnij SHL na wyniku
        writeAsm("STORE 2\n");  // line 16  // memR0 = b
        writeAsm("SUB 1\n");    // line 17  // R1 = R1 - memR0
        if($3->isNum){
            pomp(2,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n");
        }
        writeAsm("STORE 1\n");  // line 1 // memR0 = a
        writeAsm("ZERO 3\n");   // line 2 // BKup nowego a
        writeAsm("ADD 3\n");    // line 3 // R3 = a
        writeAsm("STORE 2\n");  // line 4 // memR0 = b
        writeAsm("SUB 1\n");    // line 5 // R1 - b
        jumpline = asmline + 3;
        result = "JZERO 1 " + std::to_string(jumpline); // nie wiemy czy a == b
        writeAsm(result+"\n");  // line 6
        writeAsm("INC 4\n");    // line 7 // R4 ++
        jumpline = asmline - 7;
        result = "JUMP " + std::to_string(jumpline); // a - b == 0 ?
        writeAsm(result+"\n");  // line 8
        writeAsm("INC 3\n");    // line 9      // R3 = a + 1
        writeAsm("SUB 3\n");    // line 10     // R3 = a + 1 - b
        jumpline = asmline + 2;
        result = "JZERO 3 " + std::to_string(jumpline); // nie wiemy czy a == b
        writeAsm(result+"\n");  // line 29
        writeAsm("INC 4\n");    // line 30
        writeAsm("ZERO 1\n");   // line 31
        writeAsm("STORE 4\n");  // line 32
        writeAsm("ADD 1\n");    // line 33
        writeAsm("JUMP " + std :: to_string(asmline + 5) + "\n");
        labelToLine(asmline);
        writeAsm("ZERO 1\n");
        writeAsm("JUMP " + std :: to_string(asmline + 3) + "\n");
        labelToLine(asmline);
        writeAsm("ZERO 1\n");
        writeAsm("INC 1\n");
    }
	| value '%' value  {
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
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
        std :: string result;
        writeAsm("ZERO 4\n");
        // Czysty assembler
        if($1->isNum){
            pomp(1,$1->val); //a
            pomp(4,$3->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 4\n");
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
        pompBigValue(0,address);
        address = address + 1;
        writeAsm("STORE 3\n");
        writeAsm("SUB 4\n"); // b >= a?
        writeAsm("DEC 3\n"); // b == 1
        writeAsm("JZERO 4 " + std :: to_string(asmline + 3) + "\n");
        writeAsm("JZERO 3 " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        jumpLabel("JUMP ", asmline);  // zwroc 0 bo b > a, b == 1
        // koniec testow
        pompBigValue(0,address);
        address = address + 1;
        // MOD ?? ;/
        writeAsm("JZERO 1 " + std :: to_string(asmline + 20) + "\n");
        writeAsm("STORE 1\n");  // bk a
        writeAsm("ZERO 3\n");   // bk a
        writeAsm("ADD 3\n");    // bk a
        writeAsm("STORE 2\n");  // wez b
        writeAsm("SUB 1\n");    // a -= b
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JUMP " + std :: to_string(asmline - 6) + "\n");
        writeAsm("STORE 3\n");  // bk a
        writeAsm("ZERO 4\n");   // bk a
        writeAsm("ADD 4\n");    // bk a
        writeAsm("STORE 2\n");  // wez b
        writeAsm("INC 4\n");    // a + 1
        writeAsm("SUB 4\n");    // a + 1 - b == 0?
        writeAsm("JZERO 4 " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JUMP " + std :: to_string(asmline + 6) + "\n");
        writeAsm("STORE 3\n");  // bk a
        writeAsm("ZERO 1\n");   // bk a
        writeAsm("ADD 1\n");    // bk a
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");

        // reakcje na b = 0 i b = 1
        labelToLine(asmline);
        writeAsm("ZERO 1\n");
    }
;

cond:
	value '=' value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
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
        // Napomuj R2 = a, R3 = a, R4 = b
        if($1->isNum){
            pomp(1,$1->val); //a
            pomp(3,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 3\n");
        }
        if($3->isNum){
            pomp(2,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n"); //b
        }

        // R0 = wolny address
        pompBigValue(0,address);
        address = address + 1;
        writeAsm("STORE 2\n");      // b -> memR0
        writeAsm("SUB 1\n");        // R1 = a - memR0 = a - b
        writeAsm("STORE 3\n");      // a -> memR0
        writeAsm("SUB 2");           // R2 = b - memR0 = b - a
        // a - b = 0 ?
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");    // Jezeli R1 == 0 to mamy spelniony warunek
        // skocz false
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");       // a > b wiec false
        // b - a = 0 ?
        writeAsm("JZERO 2 " + std :: to_string(asmline + 2) + "\n");    // Jezeli R2 == 0 to mamy spelniony warunek
        jumpLabel("JUMP ", asmline);  // false
        // tutaj juz jest true to mamy skoczyc
    }
	| value NE value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
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
        }// W R0 lub w R1 bedzie wynik 1 - true, 0 - false
        // Napomuj R2 = a, R3 = a, R4 = b
        if($1->isNum){
            pomp(1,$1->val); //a
            pomp(3,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 3\n");
        }
        if($3->isNum){
            pomp(2,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n"); //b
        }
        // R0 = wolny address
        pompBigValue(0,address);
        address = address + 1;
        writeAsm("STORE 2\n");      // b -> memR0
        writeAsm("SUB 1\n");        // R1 = a - memR0 = a - b
        writeAsm("STORE 3\n");      // a -> memR0
        writeAsm("SUB 2");           // R2 = b - memR0 = b - a
        writeAsm("STORE 2\n");
        writeAsm("ADD 1\n");
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");    // Jezeli R1 == 0 to mamy spelniony warunek
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");       // a > b wiec false
        jumpLabel("JUMP ", asmline);  // false
        // tutaj juz jest true to mamy skoczyc
    }
	| value '<' value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
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
        }//R1 = a MEM[R0] = b
        if($1->isNum){
            pomp(1,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
        }
        if($3->isNum){
            pomp(2,$3->val); //b
            pompBigValue(0, address + 1);
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
        jumpLabel("JUMP ", asmline);
    }
	| value '>' value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
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
        if($3->isNum){
            pomp(1,$3->val);        // R1 = b
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 1\n");   // R1 = b
        }
        if($1->isNum){
            pomp(2,$1->val);        // R2 = a
            pompBigValue(0, address + 1);
            writeAsm("STORE 2\n");  // memR0 = R2
        }
        else{
            pomp_addr(0,*$1);       // memR0 = addr.a
        }

        /* TERAZ MAMY W R1 = b MEM[R0] = a */
        // b < a lub b + 1 <= a
        writeAsm("INC 1\n");       // ++b
        writeAsm("SUB 1\n");      //R2 = R2 - memR0 = b + 1 - a = 0

        /* teraz asmline wskazuje na linie JZER1 wiec zeby przeskoczyc next inst robimy + 2 */
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");      //Jezeli R2 == 0 to mamy spelniony warunek
        jumpLabel("JUMP ", asmline);
    }
	| value LE value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
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
            pompBigValue(0, address + 1);
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

        jumpLabel("JUMP ", asmline);
    }
	| value GE value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
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
        if($3->isNum){
            pomp(1,$3->val); //a
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 1\n");
        }
        if($1->isNum){
            pomp(2,$1->val); //b
            pompBigValue(0, address + 1);
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
        jumpLabel("JUMP ", asmline);
    }
;

value:
	NUM{
        $$ = new Variable;
        $$->name = $1.str;
        $$->isNum = true;
        $$->val = atoll($1.str);
    }
	| identifier{
    }
;

identifier:
	VARIABLE{
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
	| VARIABLE '[' VARIABLE ']'{

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
	| VARIABLE '[' NUM ']'{
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
void yyerror(const char *msg){
    printf("ERROR!!!\t%s\t%s\nLINE\t%d\n",msg,yylval.token.str, yylval.token.line);
    exit(1);
}

inline void jumpLabel(std :: string const &str, int64_t line){
    labels.push(line);

    writeAsm(str);
}

inline void labelToLine(uint64_t line){
    int64_t jline;
    jline = labels.top();
    labels.pop();

    code[jline] += std :: to_string(line) + "\n";
}

int compile(const char *infile, const char *outfile){
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
