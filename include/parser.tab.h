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
#line 16 "./src/parser.y" /* yacc.c:1909  */

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

#line 80 "./include/parser.tab.h" /* yacc.c:1909  */

/* Token type.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    ASSIGN = 258,
    NE = 259,
    LE = 260,
    GE = 261,
    VAR = 262,
    _BEGIN = 263,
    END = 264,
    READ = 265,
    WRITE = 266,
    SKIP = 267,
    FOR = 268,
    FROM = 269,
    TO = 270,
    DOWNTO = 271,
    ENDFOR = 272,
    WHILE = 273,
    DO = 274,
    ENDWHILE = 275,
    IF = 276,
    THEN = 277,
    ELSE = 278,
    ENDIF = 279,
    VARIABLE = 280,
    NUM = 281,
    ERROR = 282
  };
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED

union YYSTYPE
{
#line 54 "./src/parser.y" /* yacc.c:1909  */

    yytoken token;
    Variable *var;

#line 125 "./include/parser.tab.h" /* yacc.c:1909  */
};

typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;

int yyparse (void);

#endif /* !YY_YY_INCLUDE_PARSER_TAB_H_INCLUDED  */
