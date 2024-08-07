%{
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#ifndef FMACROS
   #include "../macros.h"
#endif
#ifndef FTYPES
   #include "../types.h"
#endif
#ifndef FMISC
   #include "../misc.h"
#endif
#ifndef FDICTIONARY
   #include "../dictionary.h"
#endif
#ifndef FSQLCOMMANDS
   #include "../sqlcommands.h"
#endif
#ifndef FDATABASE
   #include "../database.h"
#endif
#ifndef FPARSER
   #include "parser.h"
#endif

extern char* yytext[];
extern FILE * yyin;
extern FILE* outFile_p;

int inside_sql_command = 0; // Adicionando a variável para rastrear comandos SQL
int in_transaction = 0; // Adicionando variável para rastrear transações

%}

%union {
    int intval;
    double floatval;
    int subtok;
    char *strval;
}

%token  INSERT      INTO        VALUES      SELECT      FROM
        CREATE      TABLE       INTEGER     VARCHAR     DOUBLE
        CHAR        PRIMARY     KEY         REFERENCES  DATABASE
        DROP        OBJECT      NUMBER      VALUE       QUIT
        LIST_TABLES LIST_TABLE  CONNECT     HELP        LIST_DBASES
        CLEAR       CONTR       WHERE       OPERADOR    RELACIONAL
        LOGICO      ASTERISCO   SINAL       FECHA_P     ABRE_P
        STRING      INDEX       ON	    BEGIN_TRANSACTION       
        END_TRANSACTION	        COMMIT_TRANSACTION      ROLLBACK_TRANSACTION;
%%
start: insert | select | create_table | create_database | drop_table | drop_database
     | table_attr | list_tables | connection | exit_program | semicolon {inside_sql_command = 0; GLOBAL_PARSER.consoleFlag = 1; return 0;}
     | help_pls | list_databases | clear | contributors | create_index | begin_transaction
     | commit_transaction | end_transaction | rollback_transaction |
     | qualquer_coisa;

/*--------------------------------------------------*/
/**************** GENERAL FUNCTIONS *****************/
/*--------------------------------------------------*/

/* CONNECTION */
connection: CONNECT OBJECT {connect(*yytext); inside_sql_command = 0; GLOBAL_PARSER.consoleFlag = 1; return 0;};

qualquer_coisa: OBJECT {inside_sql_command = 0; GLOBAL_PARSER.consoleFlag = 1; GLOBAL_PARSER.noerror = 0; return 0;};

/* EXIT */
exit_program: QUIT {exit(0);};

clear: CLEAR {clear(); inside_sql_command = 0; GLOBAL_PARSER.consoleFlag = 1; return 0;};

parentesis_open: ABRE_P {GLOBAL_PARSER.parentesis++;};

parentesis_close: FECHA_P {GLOBAL_PARSER.parentesis--;};

/* TABLE ATTRIBUTES */
table_attr: LIST_TABLE OBJECT {
    if (connected.conn_active) {
        printTable(yylval.strval);
        inside_sql_command = 0;
        GLOBAL_PARSER.consoleFlag = 1;
    } else
        notConnected();
    return 0;
};

/* LIST TABLES */
list_tables: LIST_TABLES {
    if (connected.conn_active) {
        printTable(NULL);
        inside_sql_command = 0;
        GLOBAL_PARSER.consoleFlag = 1;
    } else
        notConnected();
    return 0;
};

/* LIST DATABASES */
list_databases: LIST_DBASES {
    showDB();
    inside_sql_command = 0;
    GLOBAL_PARSER.consoleFlag = 1;
    return 0;
}

/* HELP */
help_pls: HELP {help(); inside_sql_command = 0; GLOBAL_PARSER.consoleFlag = 1; return 0;}

/* CONTRIBUTORS */
contributors: CONTR {contr(); inside_sql_command = 0; GLOBAL_PARSER.consoleFlag = 1; return 0;}

/*--------------------------------------------------*/
/****************** SQL STATEMENTS ******************/
/*--------------------------------------------------*/

/* INSERT */
insert: INSERT INTO {setMode(OP_INSERT);} table opt_column_list VALUES parentesis_open value_list parentesis_close semicolon {
    if (GLOBAL_PARSER.col_count == GLOBAL_PARSER.val_count || GLOBAL_DATA.columnName == NULL)
        GLOBAL_DATA.N = GLOBAL_PARSER.val_count;
    else {
        printf("ERROR: The column counter doesn't match the value counter.\n");
        GLOBAL_PARSER.noerror = 0;
    }
    inside_sql_command = 0;
    return 0;
};

semicolon: ';';

table: OBJECT {setObjName(yytext);};

opt_column_list: /*optional*/ | parentesis_open column_list parentesis_close;

column_list: column | column ',' column_list;

column: OBJECT {setColumnInsert(yytext);};

value_list: value | value ',' value_list;

value: VALUE {setValueInsert(yylval.strval, 'D');}
     | NUMBER {setValueInsert(yylval.strval, 'I');}
     | STRING {setValueInsert(yylval.strval, 'S');};

/* CREATE TABLE */
create_table: CREATE TABLE {setMode(OP_CREATE_TABLE);} table parentesis_open table_column_attr parentesis_close semicolon {
    GLOBAL_DATA.N = GLOBAL_PARSER.col_count;
    inside_sql_command = 0;
    return 0;
};

table_column_attr: column_create type attribute | column_create type attribute ',' table_column_attr;

type: INTEGER {setColumnTypeCreate('I');}
    | VARCHAR {setColumnTypeCreate('S');} parentesis_open NUMBER {setColumnSizeCreate(yylval.strval);} parentesis_close
    | DOUBLE {setColumnTypeCreate('D');};
    | CHAR {setColumnTypeCreate('C');};

column_create: OBJECT {setColumnCreate(yytext);};

attribute: /*optional*/
         | PRIMARY KEY {setColumnPKCreate();}
         | REFERENCES table_fk ABRE_P column_fk FECHA_P;

table_fk: OBJECT {setColumnFKTableCreate(yytext);};

column_fk: OBJECT {setColumnFKColumnCreate(yytext);};

/* DROP TABLE */
drop_table: DROP TABLE {setMode(OP_DROP_TABLE);} OBJECT {setObjName(yytext);} semicolon  {
    inside_sql_command = 0;
    return 0;
};

/* CREATE DATABASE */
create_database: CREATE DATABASE {setMode(OP_CREATE_DATABASE);} OBJECT {setObjName(yytext);} semicolon {
    inside_sql_command = 0;
    return 0;
};

/* DROP DATABASE */
drop_database: DROP DATABASE {setMode(OP_DROP_DATABASE);} OBJECT {setObjName(yytext);} semicolon {
    inside_sql_command = 0;
    return 0;
};

/* SELECT */
select: SELECT {setMode(OP_SELECT); resetSelect();} projecao
        FROM table_select where semicolon {
    inside_sql_command = 0;
    return 0;
};

table_select: OBJECT {adcTabelaSelect(yylval.strval);};

projecao: ASTERISCO {adcProjSelect(yylval.strval);}
        |  OBJECT {adcProjSelect(yylval.strval);} projecao2
        |  ABRE_P OBJECT {adcProjSelect(yylval.strval);} projecao2 FECHA_P

projecao2: /* epsilon */
          | ',' OBJECT {adcProjSelect(yylval.strval);} projecao2

where:  /* epsilon */
      | WHERE logicos

logicos: relacoes repLogicos
        |  adc_abre_p logicos FECHA_P {adcTokenWhere(yylval.strval,6);} repLogicos

adc_abre_p: ABRE_P {adcTokenWhere(yylval.strval,5);}

repLogicos: /* epsilon */
          | LOGICO {adcTokenWhere(*yytext,1);} logicos

relacoes: operacao RELACIONAL {adcTokenWhere(yylval.strval,2);} operacao

operacao: STRING {adcTokenWhere(yylval.strval,7);}
        | operando operacao2
        | OBJECT {adcTokenWhere(yylval.strval,8);} operacao2
        | adc_abre_p operacao {adcTokenWhere(yylval.strval,6);} FECHA_P operacao2

operacao2: /* epsilon */
          | operador operacao

operador: ASTERISCO {adcTokenWhere(yylval.strval,4);}
        | OPERADOR {adcTokenWhere(yylval.strval,4);}
        | sinal

sinal: '-' {adcTokenWhere(*yytext,3);} | '+' {adcTokenWhere(*yytext,3);}

operando: sinal VALUE {adcTokenWhere(yylval.strval,9);} | sinal NUMBER {adcTokenWhere(yylval.strval,9);}
        | VALUE {adcTokenWhere(yylval.strval,9);} | NUMBER {adcTokenWhere(yylval.strval,9);}

/* CREATE TABLE */
create_index: CREATE INDEX ON {setMode(OP_CREATE_INDEX);} table parentesis_open atributo parentesis_close semicolon {
    inside_sql_command = 0;
    return 0;
};

atributo: OBJECT {setColumnBtreeCreate(yytext);};

begin_transaction: BEGIN_TRANSACTION {
    if(in_transaction == 1){
        printf("already in transaction.\n");
    } else{
        begin_transaction(); 
        in_transaction = 1;
    }
    inside_sql_command = 0;
    GLOBAL_PARSER.consoleFlag = 1;
    return 0;
};

commit_transaction: COMMIT_TRANSACTION{
    if(in_transaction == 0){
        printf("not in transaction.\n");
    }
    else{
        commit_transaction();
    }
    inside_sql_command = 0;
    GLOBAL_PARSER.consoleFlag = 1;
    return 0;
};  

rollback_transaction: ROLLBACK_TRANSACTION{
    if(in_transaction == 0){
        printf("not in transaction.\n");
    }
    else{
        rollback_transaction();
        in_transaction = 0;
    }
    inside_sql_command = 0;
    GLOBAL_PARSER.consoleFlag = 1;
    return 0;
};

end_transaction: END_TRANSACTION{
    if(in_transaction == 0){
        printf("not in transaction.\n");
    }
    else{
        end_transaction();
        in_transaction = 0;
    }
    inside_sql_command = 0;
    GLOBAL_PARSER.consoleFlag = 1;
    return 0;
};

/* END */
%%
