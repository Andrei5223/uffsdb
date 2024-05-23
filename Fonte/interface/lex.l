%{
#include <stdio.h>
#ifndef FMACROS
   #include "../macros.h"
#endif
#ifndef FTYPES
   #include "../types.h"
#endif
#ifndef FPARSER
   #include "parser.h"
#endif
#include "y.tab.h"
#define YY_NO_INPUT
extern int inside_sql_command;
%}

%option nounput

%%

(?i:INSERT)                        { inside_sql_command = 1; return INSERT; }
(?i:INTO)                          { inside_sql_command = 1; return INTO; }
(?i:VALUES)                        { inside_sql_command = 1; return VALUES; }
(?i:SELECT)                        { inside_sql_command = 1; return SELECT; }
(?i:FROM)                          { inside_sql_command = 1; return FROM; }
(?i:WHERE)                         { inside_sql_command = 1; return WHERE; }
(?i:CREATE)                        { inside_sql_command = 1; return CREATE; }
(?i:TABLE)                         { inside_sql_command = 1; return TABLE; }
(?i:ON)                            { inside_sql_command = 1; return ON; }
(?i:INDEX)                         { inside_sql_command = 1; return INDEX; }
(?i:INTEGER)                       { inside_sql_command = 1; return INTEGER; }
(?i:AND)                           { inside_sql_command = 1; return LOGICO; }
(?i:OR)                            { inside_sql_command = 1; return LOGICO; }
(?i:INT)                           { inside_sql_command = 1; return INTEGER; }
(?i:VARCHAR)                       { inside_sql_command = 1; return VARCHAR; }
(?i:CHAR)                          { inside_sql_command = 1; return CHAR; }
(?i:DOUBLE)                        { inside_sql_command = 1; return DOUBLE; }
(?i:PRIMARY)                       { inside_sql_command = 1; return PRIMARY; }
(?i:KEY)                           { inside_sql_command = 1; return KEY; }
(?i:REFERENCES)                    { inside_sql_command = 1; return REFERENCES; }
(?i:DATABASE)                      { inside_sql_command = 1; return DATABASE; }
(?i:DROP)                          { inside_sql_command = 1; return DROP; }
(?i:CONTRIBUTORS)                  { inside_sql_command = 1; return CONTR; }
help                               { inside_sql_command = 1; return HELP; }
[\\][h]                            { inside_sql_command = 1; return HELP; }
[\\][h]+[^\n]*                     { invalidCommand(yytext); };
[\\][\?]                           { inside_sql_command = 1; return HELP; }
(?i:CLEAR)                         { inside_sql_command = 1; return CLEAR; }

[,]								return *yytext;
[;]								{ if (inside_sql_command) return *yytext; else /* ignore */; }
[-]								return *yytext;
[+]								return *yytext;


[)]                     {yylval.strval = yytext; return FECHA_P;};
[(]                     {yylval.strval = yytext; return ABRE_P;};
[*]                     {yylval.strval = yytext; return ASTERISCO;};
([a-zA-Z_]+[0-9_]*)+		{yylval.strval = yytext; return OBJECT;};
([\']([^']|'')*[\'])		{yylval.strval = yytext; return STRING;};
[0-9]*\.[0-9]*					{yylval.strval = yytext; return VALUE;};
[0-9]+							    {yylval.strval = yytext; return NUMBER;};
([%]|[/])       {yylval.strval = yytext; return OPERADOR;}

([>][=]|[<][=]|[=]|[!][=]|[>]|[<]) {yylval.strval = yytext; return RELACIONAL;};

\n								{
									if (GLOBAL_PARSER.mode != 0) {
										if (GLOBAL_PARSER.parentesis)
											printf("%s(# ", connected.db_name);
										else
											printf("%s-# ", connected.db_name);
									} else if (connected.conn_active) {
								 		if (GLOBAL_PARSER.consoleFlag)
							                GLOBAL_PARSER.consoleFlag = 0;
							            else
							                printf("%s=# ", connected.db_name);
									} else
								 		printf(">");
								};

[\\][c]							return CONNECT;
[\\][c]+[^ ^\n]*		{invalidCommand(yytext);};
[\\][c]+[ ]*[\n]		{invalidCommand("\\c <enter>'. Expecting '\\c DBNAME"); return 0;};
[\\][l]							return LIST_DBASES;
[\\][l]+[^\n]*			{invalidCommand(yytext);};
[\\][q]							return QUIT;
[\\][q]+[^\n]*			{invalidCommand(yytext);};
[\\][d]+						return LIST_TABLES;
[\\][d]+[^\n]*			{invalidCommand(yytext);};
[\\][t]+						return LIST_TABLE;
[\\][t]+[^ ^\n]*		{invalidCommand(yytext);};
[\\][t]+[ ]*[\n]		{invalidCommand("\\t <enter>'. Expecting '\\t TABLENAME"); return 0;};
[ \t]+							/* ignore whitespace */;
%%
