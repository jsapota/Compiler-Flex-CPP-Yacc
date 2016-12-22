%{

#include "../include/common.h"

int yylex(void);

void yyerror(const char *msg);

%}

/* we need own struct so define it before use in union */
%code requires
{
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
}


%token	DIV MOD MULT
%token	ASSIGN
%token 	SUB
%token	EQ NE LT GT LE GE
%token	VAR _BEGIN END
%token	READ WRITE SKIP
%token	FOR FROM TO DOWNTO ENDFOR
%token	WHILE DO ENDWHILE
%token	IF THEN ELSE ENDIF
%token	L_BRACKET R_BRACKET
%token	VARIABLE NUM
%token	ERROR
%token	SEMICOLON

%type <token> VARIABLE vdeclar L_BRACKET NUM R_BRACKET

%%


program:
	%empty
	| VAR vdeclar _BEGIN commands END
;

vdeclar:
	%empty
	| vdeclar VARIABLE {printf("Declared %s\n",$2.str);}
	| vdeclar VARIABLE L_BRACKET NUM R_BRACKET {printf("Declared array name %s [%s]\n",$2.str,$4.str);}
;

commands:
	command
	| commands command
;

command:
	identifier ASSIGN expr SEMICOLON
	| IF cond THEN commands ELSE commands ENDIF
	| WHILE cond DO commands ENDWHILE
	| FOR VARIABLE FROM value TO value DO commands ENDFOR
	| FOR VARIABLE FROM value DOWNTO value DO commands ENDFOR
	| READ identifier SEMICOLON
	| WRITE value SEMICOLON
	| SKIP SEMICOLON
;

expr:
	value
	| value '+' value  { printf("[BISON]ADD\n");    }
	| value '-' value  { printf("[BISON]SUB\n");    }
	| value '*' value  { printf("[BISON]MULTI\n");  }
	| value '/' value  { printf("[BISON]DIV\n");    }
	| value '%' value  { printf("[BISON]MOD\n");    }
;

cond:
	value "==" value       { printf("[BISON]EQUAL\n");   }// czy na pewno ten znak?
	| value "!="  value    { printf("[BISON]NE\n");      }
	| value "<" value      { printf("[BISON]LT\n");      }
	| value ">" value      { printf("[BISON]GT\n");      }
	| value "<=" value     { printf("[BISON]LE\n");      }
	| value "=>" value     { printf("[BISON]GE\n");      }
;

value:
	NUM
	| identifier
;

identifier:
	VARIABLE
	| VARIABLE L_BRACKET VARIABLE R_BRACKET
	| VARIABLE L_BRACKET NUM R_BRACKET
;

%%
void yyerror(const char *msg)
{
    printf("ERROR!!!\t%s\t%s\nLINE\t%d\n",msg,yylval.token.str, yylval.token.line);
    exit(1);
}
