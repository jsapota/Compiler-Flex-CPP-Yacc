%{

#include "../include/parser.tab.h"
#include <common.h>

#define YY_NO_INPUT
#define YY_NO_UNPUT

int lines = 1;

static inline int yy_lex(int token);

%}



WHITE_C 				[ \t]

%x COMMENT

%%

\n						{++lines; }
\{               		{
							BEGIN(COMMENT);
						}

<COMMENT>\}      		{
							BEGIN(INITIAL);
						}

<COMMENT>[^\\{]|[^\}]	{ }

{WHITE_C}+
^{WHITE_C}*\n			{ ++lines; }

\;						{   return yy_lex((int)';'); }

\+						{   return yy_lex((int)'+'); }
\-						{   return yy_lex((int)'-'); }
\/						{   return yy_lex((int)'/'); }
\%						{  return yy_lex((int)'%'); }
\*						{ return yy_lex((int)'*'); }

\:\=					{   return yy_lex((int)ASSIGN); }

\=						{   return yy_lex((int)'='); }
\<\>					{  return yy_lex((int)NE); }
\<						{   return yy_lex((int)'<'); }
\>						{   return yy_lex((int)'>'); }
\<\=					{   return yy_lex((int)GE); }
\>\=					{  return yy_lex((int)LE); }


VAR						{ return yy_lex(VAR); }


"BEGIN"					{ return yy_lex(_BEGIN); }
END						{ return yy_lex(END); }


READ					{ return yy_lex(READ); }
WRITE					{ return yy_lex(WRITE); }


SKIP					{ return yy_lex(SKIP); }


FOR						{ return yy_lex(FOR); }
FROM					{ return yy_lex(FROM); }
TO						{return yy_lex(TO); }
DOWNTO					{ return yy_lex(DOWNTO); }
ENDFOR					{ return yy_lex(ENDFOR); }


WHILE					{ return yy_lex(WHILE); }
DO						{ return yy_lex(DO); }
ENDWHILE				{return  yy_lex(ENDWHILE); }


IF						{return  yy_lex(IF); }
THEN					{ return yy_lex(THEN); }
ELSE					{ return yy_lex(ELSE); }
ENDIF					{ return yy_lex(ENDIF); }

\[						{   return yy_lex((int)'['); }
\]						{   return yy_lex((int)']'); }


[_a-z]+					{ return yy_lex(VARIABLE); }

[0-9]+					{ return yy_lex(NUM); }

.						{ return yy_lex(ERROR); }

%%

static inline int yy_lex(int token)
{
    if( asprintf(&yylval.token.str, "%s", yytext) == -1)
        printf("asprintf error\n");

    yylval.token.line = lines;
    return token;
}

int yywrap(void)
{
	return 1;
}
