%{

#include "../include/common.h"

int yylex(void);

void yyerror(const char *msg);

%}

/* we need own struct so define it before use in union */
%code requires
{
    #include <string.h>
    #include <map>

    typedef struct yytoken
    {
        char *str;
        int line;
    }yytoken;

    typedef struct Variable
    {

        std :: string name;

        int reg;
        int addr;
        int len;

        bool isNum;
        bool upToDate;
        bool array;
        bool init;
        bool iter;

        uint64_t val;

        uint64_t offset; /* t[1000] := a + b   offset = 1000 */
        struct Variable *varOffset; /*  t[b] := a + c  varOffset = ptr --> b*/

    }Variable;

    void inline variable_copy(Variable &dst, Variable const &src);
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
;

vdeclar:
	%empty
	| vdeclar VARIABLE
    {
        auto it = variables.find(std :: string($2.str));
        if (it != variables.end())
        {
            std :: cerr << "REDECLARED\t" << $2.str << std :: endl;
            exit(1);
        }
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
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = -1;
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
        auto it = variables.find(std :: string($2.str));
        if (it != variables.end())
        {
            std :: cerr << "REDECLARED\t" << $2.str << std :: endl;
            exit(1);
        }
        /*
            reg = -1;
            addr = -1;
            len = NUM;

            array = true;
            init = false;
            upToDate = true;
            iter = false;
        */
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = -1;
        var.isNum = false;
        var.len = atoll($4.str);
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
        /*
        id = R1
        */
    }
	| IF cond THEN commands ELSE commands ENDIF
	| WHILE cond DO commands ENDWHILE
	| FOR VARIABLE FROM value TO value DO commands ENDFOR
	| FOR VARIABLE FROM value DOWNTO value DO commands ENDFOR
	| READ identifier ';'
	| WRITE value ';'
	| SKIP ';'
;

expr:
	value
	| value '+' value  {

                        printf("[BISON]ADD\n");
                        std :: cout << $1->name << " + " << $3->name << std :: endl;
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
    }
	| value '-' value  { printf("[BISON]SUB\n");    }
	| value '*' value  { printf("[BISON]MULTI\n");  }
	| value '/' value  { printf("[BISON]DIV\n");    }
	| value '%' value  { printf("[BISON]MOD\n");    }
;

cond:
	value '=' value       { printf("[BISON]EQUAL\n");
                /*
                    Do wymyslenia: jak sie skapnac ze cos jest w relacji
                    a == b ??
                    SUB
                    JZERO
                    INC
                */
  }
	| value NE  value    { printf("[BISON]NE\n");      }
	| value '<' value      { printf("[BISON]LT\n");      }
	| value '>' value      { printf("[BISON]GT\n");      }
	| value LE value     { printf("[BISON]LE\n");      }
	| value GE value     { printf("[BISON]GE\n");      }
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
