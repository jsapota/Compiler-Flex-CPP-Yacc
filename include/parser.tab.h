/* A Bison parser, made by GNU Bison 3.0.4.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

#ifndef YY_YY_INCLUDE_PARSER_TAB_H_INCLUDED
# define YY_YY_INCLUDE_PARSER_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif
/* "%code requires" blocks.  */
#line 13 "./src/parser.y" /* yacc.c:1909  */

    typedef struct yytoken
    {
        char *str;
        int line;
    }yytoken;

#line 52 "./include/parser.tab.h" /* yacc.c:1909  */

/* Token type.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    DIV = 258,
    MOD = 259,
    MULT = 260,
    ASSIGN = 261,
    SUB = 262,
    EQ = 263,
    NE = 264,
    LT = 265,
    GT = 266,
    LE = 267,
    GE = 268,
    VAR = 269,
    _BEGIN = 270,
    END = 271,
    READ = 272,
    WRITE = 273,
    SKIP = 274,
    FOR = 275,
    FROM = 276,
    TO = 277,
    DOWNTO = 278,
    ENDFOR = 279,
    WHILE = 280,
    DO = 281,
    ENDWHILE = 282,
    IF = 283,
    THEN = 284,
    ELSE = 285,
    ENDIF = 286,
    L_BRACKET = 287,
    R_BRACKET = 288,
    VARIABLE = 289,
    NUM = 290,
    ERROR = 291,
    SEMICOLON = 292
  };
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED

union YYSTYPE
{
#line 23 "./src/parser.y" /* yacc.c:1909  */

    yytoken token;

#line 106 "./include/parser.tab.h" /* yacc.c:1909  */
};

typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;

int yyparse (void);

#endif /* !YY_YY_INCLUDE_PARSER_TAB_H_INCLUDED  */
