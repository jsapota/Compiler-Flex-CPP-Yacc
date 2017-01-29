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

static cln :: cl_I address = 0;
extern FILE *yyin;

uint64_t asmline = 0;

static std :: stack <int64_t> looplines;

static std :: stack <Variable*> iterators;

static std :: map<std :: string, Variable> variables;

std :: vector <std :: string> code;

static std :: stack <int64_t> labels;

inline void jumpLabel(std :: string const &str, int64_t line); // jump to false
inline void labelToLine(uint64_t line);

%}

%code requires{
    #include<common.h>
    #include<variable.h>

    typedef struct yytoken
    {
        char *str;
        int line;
    }yytoken;
}

%union{
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

        auto it = variables.find(std :: string($2.str));
        if (it != variables.end())
        {
            std :: cerr << "ERROR: REDECLARED\t" << $2.str << std :: endl;
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

        auto it = variables.find(std :: string($2.str));
        if (it != variables.end())
        {
            std :: cerr << "ERROR: REDECLARED\t" << $2.str << std :: endl;
            exit(1);
        }
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = address;
        var.isNum = false;
        var.len = strtoll ($4.str, &$4.str, 10);
        address = address + var.len;
        if(var.len == 0)
        {
            std :: cerr << "ERROR: SIZE OF ARRAY CANT BE 0\t" << $2.str << std :: endl;
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
        auto it = variables[$1->name];
        if (it.iter){
            std :: cerr << "ERROR: VARIABLE IS ITERATOR\t" << $1->name << std :: endl;
            exit(1);
        }
        if(it.array){
            if(it.varOffset != NULL){
                auto it2 = variables[it.varOffset->name];
                if(!it2.init){
                    std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                    exit(1);
                }
            }
        }
        pomp_addr(0, *$1);
        writeAsm("STORE 1\n"); //
        variables[$1->name].init = true;
    }
	| ifbeg ifmid ifend
	| whilebeg whileend
	| forbegTO forendTO
	| forbegDOWNTO forendDOWNTO
	| READ identifier ';'{

         auto it = variables[$2->name];
         if (it.iter){
             std :: cerr << "ERROR: VARIABLE IS ITERATOR\t" << $2->name << std :: endl;
             exit(1);
         }
         if(it.array){
             if(it.varOffset != NULL){
                 auto it2 = variables[it.varOffset->name];
                 if(!it2.init){
                     std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                     exit(1);
                 }
             }
         }
         writeAsm("GET 1\n");
         pomp_addr(0, *$2);
         writeAsm("STORE 1\n");
         variables[$2->name].init = true;

    }
	| WRITE value ';'{

        if(! $2->isNum)
        {
            auto it = variables[$2->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $2->name << std :: endl;
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
    }
ifmid:
    commands ELSE{
        labelToLine(asmline + 1);
        jumpLabel("JUMP ",asmline);
    }
ifend:
    commands ENDIF{
            labelToLine(asmline);
    }
prewhile:
    WHILE
    {
        looplines.push(asmline);
    }
    ;
whilebeg:
    prewhile cond DO{
    }
    ;
whileend:
    commands ENDWHILE{
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
        if(! $4->isNum)
        {
            auto it = variables[$4->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $4->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(! $6->isNum)
        {
            auto it = variables[$6->name];
            if (! it.isNum && !it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $6->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }

        auto it2 = variables.find(std :: string($2.str));
        if (it2 != variables.end())
        {
            std :: cerr << "ERROR: REDECLARED ITERATOR\t" << $2.str << std :: endl;
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
        var.init = true;
        var.upToDate = true;
        var.iter = true;
        var.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );

        Variable *iterator = new Variable;
        variable_copy(*iterator, var);

        iterators.push(iterator);

        if(! $4->isNum)
        {
            pomp_addr(0, *$4);
            writeAsm("LOAD 1\n");
        }
        else
            pomp(1, $4->val);

        pomp_addr(0, var);
        writeAsm("STORE 1\n");

        Variable var2;
        var2.name = std :: string($2.str) + "2";
        var2.reg = -1;
        var2.addr = address;
        address = address + 1;
        var2.len = 0;
        var2.isNum = false;
        var2.array = false;
        var2.init = true;
        var2.upToDate = true;
        var2.iter = true;
        var2.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var2.name,var2) );

        if(! $6->isNum)
        {
            pomp_addr(0, *$6);
            writeAsm("LOAD 1\n");
            writeAsm("INC 1\n");
        }
        else
        {
            pomp(1, $6->val);
            writeAsm("INC 1\n");
        }


        if(! $4->isNum)
            pomp_addr(0, *$4);
        else
        {
            pomp(2, $4->val);
            pompBigValue(0, address);
            writeAsm("STORE 2\n");
        }

        writeAsm("SUB 1\n");

        pomp_addr(0, var2);

        writeAsm("STORE 1\n");

        int64_t line = asmline;
        looplines.push(line);

        pomp_addr(0, var2);
        writeAsm("LOAD 1\n");
        jumpLabel("JZERO 1 ", asmline);
    }
    ;
forendTO:
    commands ENDFOR{

        Variable *var;
        var = iterators.top();
        iterators.pop();

        pomp_addr(0, *var);
        writeAsm("LOAD 1\n");
        writeAsm("INC 1\n");
        writeAsm("STORE 1\n");

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

        auto it2 = variables.find(var->name);
        variables.erase(it2);

        auto it3 = variables.find(it.name);
        variables.erase(it3);

    };
forbegDOWNTO:
    FOR VARIABLE FROM value DOWNTO value DO{

        if(! $4->isNum)
        {
            auto it = variables[$4->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $4->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(! $6->isNum)
        {
            auto it = variables[$6->name];
            if (! it.isNum && !it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $6->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }

        auto it2 = variables.find(std :: string($2.str));
        if (it2 != variables.end())
        {
            std :: cerr << "ERROR: REDECLARED ITERATOR\t" << $2.str << std :: endl;
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
        var.init = true;
        var.upToDate = true;
        var.iter = true;
        var.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );

        Variable *iterator = new Variable;
        variable_copy(*iterator, var);

        iterators.push(iterator);

        if(! $4->isNum)
        {
            pomp_addr(0, *$4);
            writeAsm("LOAD 1\n");
        }
        else
            pomp(1, $4->val);

        pomp_addr(0, var);
        writeAsm("STORE 1\n");

        Variable var2;
        var2.name = std :: string($2.str) + "2";
        var2.reg = -1;
        var2.addr = address;
        address = address + 1;
        var2.len = 0;
        var2.isNum = false;
        var2.array = false;
        var2.init = true;
        var2.upToDate = true;
        var2.iter = true;
        var2.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var2.name,var2) );

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


        if(! $6->isNum)
            pomp_addr(0, *$6);
        else
        {
            pomp(2, $6->val);
            pompBigValue(0, address);
            writeAsm("STORE 2\n");
        }

        writeAsm("SUB 1\n");

        pomp_addr(0, var2);

        writeAsm("STORE 1\n");

        int64_t line = asmline;
        looplines.push(line);

        pomp_addr(0, var2);
        writeAsm("LOAD 1\n");
        jumpLabel("JZERO 1 ", asmline);
    };
forendDOWNTO:
    commands ENDFOR{
        Variable *var;
        var = iterators.top();
        iterators.pop();

        pomp_addr(0, *var);
        writeAsm("LOAD 1\n");
        writeAsm("DEC 1\n");
        writeAsm("STORE 1\n");

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
                auto it = variables[$1->name];
                if (!it.init)
                    {
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                        exit(1);
                    }
                if(it.array){
                    if(it.varOffset != NULL){
                        auto it2 = variables[it.varOffset->name];
                        if(!it2.init){
                            std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                            exit(1);
                        }
                    }
                }
                pomp_addr(0, *$1);
                writeAsm("LOAD 1\n");
            }
    }
	| value '+' value  {
            if(!$1->isNum){
            auto it = variables[$1->name];
                if (!it.init)
                {
                    std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                    exit(1);
                }
                if(it.array){
                    if(it.varOffset != NULL){
                        auto it2 = variables[it.varOffset->name];
                        if(!it2.init){
                            std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                            exit(1);
                        }
                    }
                }
            }
            if(!$3->isNum){
                auto it = variables[$3->name];
                if (!it.init)
                {
                    std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                    exit(1);
                }
                if(it.array){
                    if(it.varOffset != NULL){
                        auto it2 = variables[it.varOffset->name];
                        if(!it2.init){
                            std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                            exit(1);
                        }
                    }
                }
            }
                // stala i stala
            if($1->isNum && $3->isNum){
                    cln :: cl_I a = $1->val;
                    cln :: cl_I b = $3->val;
                    pompBigValue(1,a + b);

            }
            else{
                if(!$1->isNum && $3->isNum){
                    pomp_addr(0,*$1);
                    pomp(1,$3->val);
                    writeAsm("ADD 1\n");
                }
                if($1->isNum && !$3->isNum){
                    pomp_addr(0,*$3);
                    pomp(1,$1->val);
                    writeAsm("ADD 1\n");
                }
                if(!$1->isNum && !$3->isNum){
                    pomp_addr(0,*$1);
                    writeAsm("LOAD 1\n");
                    pomp_addr(0,*$3);
                    writeAsm("ADD 1\n");
                }
            }
    }
	| value '-' value  {
            if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init)
                {
                    std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                    exit(1);
                }
                if(it.array){
                    if(it.varOffset != NULL){
                        auto it2 = variables[it.varOffset->name];
                        if(!it2.init){
                            std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                            exit(1);
                        }
                    }
                }
            }
            if(!$3->isNum){
                auto it = variables[$3->name];
                if (!it.init)
                {
                    std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                    exit(1);
                }
                if(it.array){
                    if(it.varOffset != NULL){
                        auto it2 = variables[it.varOffset->name];
                        if(!it2.init){
                            std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                            exit(1);
                        }
                    }
                }
            }
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
            if(!$1->isNum && $3->isNum){
                pomp_addr(0,*$1);
                writeAsm("LOAD 1\n");
                pomp(2,$3->val);
                pompBigValue(0,address + 1);
                writeAsm("STORE 2\n");
                writeAsm("SUB 1\n");
            }
            if($1->isNum && !$3->isNum){
                pomp_addr(0,*$3);
                pomp(1,$1->val);
                writeAsm("SUB 1\n");
            }
            if(!$1->isNum && !$3->isNum){
                pomp_addr(0,*$1);
                writeAsm("LOAD 1\n");
                pomp_addr(0,*$3);
                writeAsm("SUB 1\n");
            }
        }
    }
	| value '*' value  {
        if(!$1->isNum){
        auto it = variables[$1->name];
        if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if($1->isNum)
            pomp(1,$1->val);
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
        }
        if($3->isNum){
            pomp(2,$3->val);
            pomp(3,$3->val);
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n");
            writeAsm("LOAD 3\n");
        }
        jumpLabel("JZERO 2 ", asmline);
        writeAsm("DEC 2\n");
        jumpLabel("JZERO 2 ", asmline);
        pompBigValue(0,address);
        address = address + 1;
        writeAsm("ZERO 4\n");
        writeAsm("JODD 3 " + std::to_string(asmline + 2)+"\n");
        writeAsm("JUMP " + std::to_string(asmline + 9)+"\n");
        writeAsm("STORE 1\n");
        writeAsm("ADD 4\n");
        writeAsm("DEC 2\n");
        writeAsm("SHR 2\n");
        writeAsm("SHL 1\n");
        writeAsm("DEC 3\n");
        writeAsm("SHR 3\n");
        writeAsm("JUMP " + std::to_string(asmline + 4)+"\n");
        writeAsm("SHR 2\n");
        writeAsm("SHL 1\n");
        writeAsm("SHR 3\n");
        writeAsm("DEC 3\n");
        writeAsm("JZERO 3 " + std::to_string(asmline + 3)+"\n");
        writeAsm("INC 3\n");
        writeAsm("JUMP " + std::to_string(asmline - 16)+"\n");
        writeAsm("STORE 4\n");
        writeAsm("ADD 1\n");
        writeAsm("JUMP " + std :: to_string(asmline + 3) + "\n");
        labelToLine(asmline);
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        labelToLine(asmline);
        writeAsm("ZERO 1\n");
    }
	| value '/' value  {
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        cln :: cl_I smietnik = address;
        cln :: cl_I a = address + 1;
        cln :: cl_I b = address + 2;
        cln :: cl_I aBk = address + 3;
        cln :: cl_I wynik = address + 4;
        cln :: cl_I poWszystkim = address + 5;
        pompBigValue(0, wynik);
        writeAsm("ZERO 4\n");
        writeAsm("STORE 4\n");
        if($1->isNum){
            pomp(1,$1->val);
            pomp(3,$1->val);
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 3\n");
        }
        if($3->isNum){
            pomp(2,$3->val);
            pomp(4,$3->val);
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n");
            writeAsm("LOAD 4\n");
        }
        pompBigValue(0, b);
        writeAsm("STORE 2\n");
        pompBigValue(0, a);
        writeAsm("STORE 1\n");
        pompBigValue(0, smietnik);


        jumpLabel("JZERO 1 ", asmline);
        jumpLabel("JZERO 2 ", asmline);
        // a == b
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        writeAsm("STORE 3\n");
        writeAsm("SUB 2\n");
        writeAsm("STORE 2\n");
        writeAsm("ADD 1\n");
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        jumpLabel("JUMP ", asmline);
        pompBigValue(0, b);
        writeAsm("LOAD 2\n");
        pompBigValue(0, a);
        writeAsm("LOAD 1\n");
        pompBigValue(0, smietnik);
        writeAsm("STORE 4\n");
        writeAsm("SUB 3\n");
        jumpLabel("JZERO 3 ", asmline);
        jumpLabel("JZERO 2 ", asmline);
        writeAsm("DEC 2\n");
        jumpLabel("JZERO 2 ", asmline);
        writeAsm("DEC 2\n");
        jumpLabel("JZERO 2 ", asmline);
        writeAsm("INC 2\n");
        writeAsm("INC 2\n");


        writeAsm("ZERO 4\n");
        writeAsm("INC 4\n");
        int startLine = asmline;
        writeAsm("STORE 1\n");
        writeAsm("LOAD 3\n");
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        jumpLabel("JZERO 1 ", asmline);
        writeAsm("ADD 1\n");
        writeAsm("JZERO 4 " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        writeAsm("INC 4\n");
        writeAsm("SHL 2\n");
        writeAsm("SHL 4\n");
        writeAsm("JUMP " + std :: to_string(startLine) +"\n");
        labelToLine(asmline);
        writeAsm("SHR 2\n");
        writeAsm("SHR 4\n");
        writeAsm("STORE 3\n");
        writeAsm("LOAD 1\n");
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        pompBigValue(0, a);
        writeAsm("STORE 1\n");
        pompBigValue(0, wynik);
        writeAsm("LOAD 3\n");
        pompBigValue(0, smietnik);
        writeAsm("STORE 4\n");
        writeAsm("ADD 3\n");
        pompBigValue(0, wynik);
        writeAsm("STORE 3\n");
        pompBigValue(0, b);
        writeAsm("LOAD 2\n");
        pompBigValue(0, smietnik);
        writeAsm("ZERO 4\n");
        writeAsm("STORE 1\n");
        writeAsm("LOAD 3\n");
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        writeAsm("JZERO 1 " + std :: to_string(asmline + 4) + "\n");
        writeAsm("STORE 3\n");
        writeAsm("LOAD 1\n");
        writeAsm("JUMP " + std :: to_string(startLine) + "\n");
        pompBigValue(0, a);
        writeAsm("LOAD 1\n");
        writeAsm("LOAD 3\n");
        writeAsm("INC 1\n");
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        jumpLabel("JZERO 1 ", asmline);
        pompBigValue(0, wynik);
        writeAsm("LOAD 3\n");
        writeAsm("INC 3\n");
        writeAsm("STORE 3\n");
        labelToLine(asmline);
        pompBigValue(0, wynik);
        writeAsm("LOAD 1\n");
        writeAsm("JUMP " + std :: to_string(asmline + 7) + "\n");

        labelToLine(asmline);
        writeAsm("SHR 1\n");
        labelToLine(asmline);
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        labelToLine(asmline);
        labelToLine(asmline);
        writeAsm("ZERO 1\n");
        writeAsm("JUMP " + std :: to_string(asmline + 6) + "\n");
        labelToLine(asmline);
        writeAsm("JUMP " + std :: to_string(asmline + 3) + "\n");
        labelToLine(asmline);
        labelToLine(asmline);
        writeAsm("ZERO 1\n");
        writeAsm("JUMP " + std :: to_string(asmline + 3) + "\n");
        writeAsm("ZERO 1\n");
        writeAsm("INC 1\n");
        address = poWszystkim;
    }
	| value '%' value  {
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        cln :: cl_I smietnik = address;
        cln :: cl_I a = address + 1;
        cln :: cl_I b = address + 2;
        cln :: cl_I aBk = address + 3;
        cln :: cl_I wynik = address + 4;
        cln :: cl_I poWszystkim = address + 5;
        pompBigValue(0, wynik);
        writeAsm("ZERO 4\n");
        writeAsm("STORE 4\n");
        if($1->isNum){
            pomp(1,$1->val);
            pomp(3,$1->val);
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 3\n");
        }
        if($3->isNum){
            pomp(2,$3->val);
            pomp(4,$3->val);
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n");
            writeAsm("LOAD 4\n");
        }
        pompBigValue(0, b);
        writeAsm("STORE 2\n");
        pompBigValue(0, a);
        writeAsm("STORE 1\n");
        pompBigValue(0, aBk);
        writeAsm("STORE 1\n");
        pompBigValue(0, smietnik);

        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        writeAsm("STORE 3\n");
        writeAsm("SUB 2\n");
        writeAsm("STORE 2\n");
        writeAsm("ADD 1\n");
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        jumpLabel("JUMP ", asmline);
        pompBigValue(0, b);
        writeAsm("LOAD 2\n");
        pompBigValue(0, a);
        writeAsm("LOAD 1\n");
        pompBigValue(0, smietnik);
        writeAsm("STORE 4\n");
        writeAsm("SUB 3\n");
        jumpLabel("JZERO 3 ", asmline);
        jumpLabel("JZERO 2 ", asmline);
        writeAsm("DEC 2\n");
        jumpLabel("JZERO 2 ", asmline);
        writeAsm("INC 2\n");

        int startLine = asmline;
        writeAsm("STORE 1\n");
        writeAsm("LOAD 3\n");
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        jumpLabel("JZERO 1 ", asmline);
        writeAsm("ADD 1\n");
        writeAsm("SHL 2\n");
        writeAsm("JUMP " + std :: to_string(startLine) +"\n");

        labelToLine(asmline);
        writeAsm("SHR 2\n");
        writeAsm("STORE 3\n");
        writeAsm("LOAD 1\n");
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        pompBigValue(0, a);
        writeAsm("STORE 1\n");
        pompBigValue(0, b);
        writeAsm("LOAD 2\n");
        pompBigValue(0, smietnik);

        writeAsm("STORE 1\n");
        writeAsm("LOAD 3\n");
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        writeAsm("JZERO 1 " + std :: to_string(asmline + 4) + "\n");
        writeAsm("STORE 3\n");
        writeAsm("LOAD 1\n");
        writeAsm("JUMP " + std :: to_string(startLine) + "\n");
        pompBigValue(0, a);
        writeAsm("LOAD 1\n");
        writeAsm("LOAD 3\n");
        writeAsm("INC 3\n");
        pompBigValue(0, smietnik);
        writeAsm("STORE 2\n");
        writeAsm("SUB 3\n");
        pompBigValue(0, a);
        writeAsm("LOAD 4\n");
        jumpLabel("JZERO 3 ", asmline);
        writeAsm("JUMP " + std :: to_string(asmline + 5) + "\n");
        labelToLine(asmline);
        writeAsm("STORE 4\n");
        writeAsm("ZERO 1\n");
        writeAsm("ADD 1\n");
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");

        labelToLine(asmline);
        labelToLine(asmline);
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        labelToLine(asmline);
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        labelToLine(asmline);
        writeAsm("ZERO 1\n");
        jumpLabel("JUMP ", asmline);
        pompBigValue(0, aBk);
        writeAsm("LOAD 1\n");
        labelToLine(asmline);
        address = poWszystkim;

    }
;

cond:
	value '=' value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if($1->isNum){
            pomp(1,$1->val);
            pomp(3,$1->val);
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 3\n");
        }
        if($3->isNum){
            pomp(2,$3->val);
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n");
        }

        pompBigValue(0,address);
        address = address + 1;
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        writeAsm("STORE 3\n");
        writeAsm("SUB 2\n");
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JZERO 2 " + std :: to_string(asmline + 2) + "\n");
        jumpLabel("JUMP ", asmline);
    }
	| value NE value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if($1->isNum){
            pomp(1,$1->val);
            pomp(3,$1->val);
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
            writeAsm("LOAD 3\n");
        }
        if($3->isNum){
            pomp(2,$3->val);
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 2\n");
        }
        pompBigValue(0,address);
        address = address + 1;
        writeAsm("STORE 2\n");
        writeAsm("SUB 1\n");
        writeAsm("STORE 3\n");
        writeAsm("SUB 2\n");
        writeAsm("STORE 2\n");
        writeAsm("ADD 1\n");
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
        writeAsm("JUMP " + std :: to_string(asmline + 2) + "\n");
        jumpLabel("JUMP ", asmline);
    }
	| value '<' value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if($1->isNum){
            pomp(1,$1->val);
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
        }
        if($3->isNum){
            pomp(2,$3->val);
            pompBigValue(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$3);
        }

        writeAsm("INC 1\n");
        writeAsm("SUB 1\n");

        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
        jumpLabel("JUMP ", asmline);
    }
	| value '>' value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if($3->isNum){
            pomp(1,$3->val);
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 1\n");
        }
        if($1->isNum){
            pomp(2,$1->val);
            pompBigValue(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$1);
        }

        writeAsm("INC 1\n");
        writeAsm("SUB 1\n");

        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
        jumpLabel("JUMP ", asmline);
    }
	| value LE value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if($1->isNum){
            pomp(1,$1->val);
        }
        else{
            pomp_addr(0,*$1);
            writeAsm("LOAD 1\n");
        }
        if($3->isNum){
            pomp(2,$3->val);
            pompBigValue(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$3);
        }
        writeAsm("SUB 1\n");

        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
        jumpLabel("JUMP ", asmline);
    }
	| value GE value{
        if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init){
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
            if(it.array){
                if(it.varOffset != NULL){
                    auto it2 = variables[it.varOffset->name];
                    if(!it2.init){
                        std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it.name << std :: endl;
                        exit(1);
                    }
                }
            }
        }
        if($3->isNum){
            pomp(1,$3->val);
        }
        else{
            pomp_addr(0,*$3);
            writeAsm("LOAD 1\n");
        }
        if($1->isNum){
            pomp(2,$1->val);
            pompBigValue(0, address + 1);
            writeAsm("STORE 2\n");
        }
        else{
            pomp_addr(0,*$1);
        }

        writeAsm("SUB 1\n");
        writeAsm("JZERO 1 " + std :: to_string(asmline + 2) + "\n");
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
	| identifier
;

identifier:
	VARIABLE{
        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "ERROR: NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }
        Variable var = variables[std  :: string($1.str)];
        if( var.array){
            std :: cerr << "ERROR: VARIABLE IS ARRAY" << $1.str << std :: endl;
            exit(1);
        }


        $$ = new Variable;
        variable_copy(*$$, var);
    }
	| VARIABLE '[' VARIABLE ']'{

        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "ERROR: VARIABLE NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }
        Variable var = variables[std  :: string($1.str)];
        if( !var.array){
            std :: cerr << "ERROR: VARIABLE ISNT ARRAY" << $1.str << std :: endl;
            exit(1);
        }

        if(var.array){
            if(var.varOffset != NULL){
                auto it2 = variables[var.varOffset->name];
                if(!it2.init){
                    std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << var.name << std :: endl;
                    exit(1);
                }
            }
        }
        auto it2 = variables[std  :: string($3.str)];
        if(!it2.init){
            std :: cerr << "ERROR: VARIABLE NOT INITIALIZED\t" << it2.name << std :: endl;
            exit(1);
        }

        it = variables.find(std :: string($3.str));
        if (it == variables.end())
        {
            std :: cerr << "ERROR: VARIABLE NOT DECLARED\t" << $3.str << std :: endl;
            exit(1);
        }

        var = variables[std  :: string($3.str)];
        if( var.array){
            std :: cerr << "ERROR: VARIABLE CANT BE ARRAY" << $3.str << std :: endl;
            exit(1);
        }


        var = variables[std  :: string($1.str)];
        Variable var2 = variables[std  :: string($3.str)];


        Variable *varptr1 = new Variable;
        variable_copy(*varptr1, var);
        Variable *varptr2 = new Variable;
        variable_copy(*varptr2, var2);
        varptr1->varOffset = varptr2;
        $$ = new Variable;
        variable_copy(*$$, *varptr1);
    }
	| VARIABLE '[' NUM ']'{
        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "ERROR: VARIABLE NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }

        Variable var = variables[std  :: string($1.str)];
        if( !var.array){
            std :: cerr << "ERROR: VARIABLE ISNT ARRAY\t" << $1.str << std :: endl;
            exit(1);
        }
        if( var.len <= atoll($3.str)){
            std :: cerr << "ERROR: INDEX OUT OF RANGE\t" << $1.str << std :: endl;
            exit(1);
        }
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
