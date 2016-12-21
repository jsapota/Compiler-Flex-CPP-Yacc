%{

#include "../include/parser.tab.h"
#include "../include/common.h"

#define YY_NO_INPUT
#define YY_NO_UNPUT

int lines = 1;

#ifdef DEBUG_MODE
    #define YY_PRINT(fmt, ...) \
        printf(fmt, ##__VA_ARGS__);
#else
    #define YY_PRINT(fmt, ...)
#endif

#define YY_LEX(__token) \
    do{ \
        YY_PRINT("[LEX]\t%s\n", #__token); \
        if( asprintf(&yylval.token.str, "%s", yytext) == -1) \
            printf("asprintf error\n"); \
        yylval.token.line = lines; \
        return __token; \
    }while(0)

%}



WHITE_C 				[ \t]

%x COMMENT

%%

\n						{ printf("[LEX]NEW LINE\t Lines: %d\n", ++lines); }
\{               		{
							printf("[LEX]\tBEGIN COMMENT\n");
							BEGIN(COMMENT);
						}

<COMMENT>\}      		{
							printf("[LEX]\tEND COMMENT\n");
							BEGIN(INITIAL);
						}

<COMMENT>[^\\{]|[^\}]	{ printf("[LEX]\tCOMMENT\t%s\n",yytext); }

{WHITE_C}+
^{WHITE_C}*\n			{ printf("[LEX]NEW LINE\t Lines: %d\n", ++lines); }

\n						{ printf("[LEX]NEW LINE\t Lines: %d\n", ++lines); }

\;						{ YY_LEX(SEMICOLON); }

\+						{   YY_PRINT("[LEX]\t%s\n", "+");
                          return '+'; }
\-						{ YY_LEX(SUB); }
\/						{ YY_LEX(DIV); }
\%						{ YY_LEX(MOD); }
\*						{ YY_LEX(MULT); }

\:\=					{ YY_LEX(ASSIGN); }

\=						{ YY_LEX(EQ); }
\<\>					{ YY_LEX(NE); }
\<						{ YY_LEX(LT); }
\>						{ YY_LEX(GT); }
\<\=					{ YY_LEX(LE); }
\>\=					{ YY_LEX(GE); }


VAR						{ YY_LEX(VAR); }


"BEGIN"					{ YY_LEX(_BEGIN); }
END						{ YY_LEX(END); }


READ					{ YY_LEX(READ); }
WRITE					{ YY_LEX(WRITE); }


SKIP					{ YY_LEX(SKIP); }


FOR						{ YY_LEX(FOR); }
FROM					{ YY_LEX(FROM); }
TO						{ YY_LEX(TO); }
DOWNTO					{ YY_LEX(DOWNTO); }
ENDFOR					{ YY_LEX(ENDFOR); }


WHILE					{ YY_LEX(WHILE); }
DO						{ YY_LEX(DO); }
ENDWHILE				{ YY_LEX(ENDWHILE); }


IF						{ YY_LEX(IF); }
THEN					{ YY_LEX(THEN); }
ELSE					{ YY_LEX(ELSE); }
ENDIF					{ YY_LEX(ENDIF); }

\[						{ YY_LEX(L_BRACKET); }
\]						{ YY_LEX(R_BRACKET); }


[_a-z]+					{ YY_LEX(VARIABLE); }

[0-9]+					{ YY_LEX(NUM); }

.						{ YY_LEX(ERROR); }

%%

int yywrap(void)
{
	return 1;
}
