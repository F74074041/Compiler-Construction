/*	Definition section */
%{
    #include "common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    #define codegen(...) \
        do { \
            for (int i = 0; i < INDENT; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;
    
    /* Other global variables */
    FILE *fout = NULL;
    bool HAS_ERROR = false;
    int INDENT = 0;
    typedef struct sym {
    	bool open;
    	char*name;
    	char*type;
    	int addr;
    	int line;
    	char*et;
    } sym;
    sym s[5][5];
	int forstack[5];
	int ifstack[5];
    int scope = 0;
    int addr = 0;
    int flag = 0,flag1=0,error=0;
	int isarr=0,boolline=0,cmpline=0,tmp=0,forline=0,ifline=0;
	bool isfor=false;
	char ss[50]={};
	char *tt="";
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new function if needed. */
    void create_symbol(/* ... */);
    void insert_symbol(int scope,char*name,char*type,int line,char*et);
    int lookup_symbol(int scope,char*name);
    void dump_symbol(int scope);
    char* findtype (int scope,char*name);
	void print_val(char*type);
	int pop();
	int pop2();
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}
/* Token without return */
%token INT FLOAT BOOL STRING
%token ';' '(' ')' '[' ']' '{' '}'
%left '+' '-'
%left '*' '/' '%'
%token INC DEC ASSIGN ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token GTR LSS GEQ LEQ EQL NEQ AND OR NOT TRUE FALSE
%token PRINT IF ELSE FOR WHILE
%nonassoc NEG POS IFX
/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT
%token <s_val> IDENT
/* Nonterminal with return, which need to sepcify type */
%type <s_val> type id id2 Literal val term unary
/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%
Program
    : Program stmts
    | 
;

type
    : INT { $$="int"; flag=1; }
    | FLOAT { $$="float"; flag=1;}
    | STRING{ $$="string"; flag=1;}
    | BOOL{ $$="bool"; flag=1;}
;

Literal
    : INT_LIT {
        $$ = "int";
        fprintf(fout,"ldc %d\n", $<i_val>1);
    }
    | FLOAT_LIT {
        $$ = "float";
        fprintf(fout,"ldc %.6f\n", $<f_val>1);
    }
    | STRING_LIT{
        $$ = "string";
        fprintf(fout,"ldc \"%s\"\n", $<s_val>1);
    }
    | '(' type ')' Literal { if(strcmp($2,"int")==0&&strcmp($4,"float")==0)
                               fprintf(fout,"f2i\n");
                             else if(strcmp($2,"float")==0&&strcmp($4,"int")==0)
                               fprintf(fout,"i2f\n");
                            $$=$2;
                            }
    | '(' type ')' id2 {
                        if(strcmp($2,"int")==0&&strcmp(findtype(scope,$4),"float")==0)
                            fprintf(fout,"f2i\n");
                        else if(strcmp($2,"float")==0&&strcmp(findtype(scope,$4),"int")==0)
                            fprintf(fout,"i2f\n");
                        else
                            printf("%s\n",findtype(scope,$4));
                        $$=$2;
                      }

    | id2 {$$=findtype(scope,$1);}
    | '(' val ')'{$$=$2;}
    | bool1 {$$="1";}
;

bool1
    : TRUE { fprintf(fout,"iconst_1\n");}
    | FALSE { fprintf(fout,"iconst_0\n");}
;

id
    : IDENT {   $$ = $1;
                if(lookup_symbol(scope,$<s_val>1)==-1){
                    printf("error:%d: undefined: %s\n",yylineno,$1);
				    HAS_ERROR = true;
				}
            }
;

id2 
    : id '[' { fprintf(fout,"aload %d\n",lookup_symbol(scope,$1));} val ']' {$$=$1; fprintf(fout,"%caload\n",findtype(scope,$1)[0]);}
    | id {	$$=$1; 
			if(strcmp(findtype(scope,$1),"int")==0||strcmp(findtype(scope,$1),"float")==0)
				fprintf(fout,"%cload %d\n",findtype(scope,$1)[0],lookup_symbol(scope,$1));
			else if(strcmp(findtype(scope,$1),"bool")==0)
				fprintf(fout,"iload %d\n",lookup_symbol(scope,$1));
			else
				fprintf(fout,"aload %d\n",lookup_symbol(scope,$1));
		 }
;

stmts
                                                                                                                                                                                          
    : stmts stmt
    | stmt
;

stmt
    : declstmt
    | Block
    | IfStmt
    | LoopStmt
    | PrintStmt
    | expr
;

expr
    : assign_expr
    | val
    | error_expr
;

error_expr
    : val OR val sel { flag1=1; HAS_ERROR = true; printf("error:%d: invalid operation: (operator OR not defined on %s)\n",yylineno-2,$3); /*printf("OR\n");*/}                   
    | val AND val sel  { HAS_ERROR = true; printf("error:%d: invalid operation: (operator AND not defined on %s)\n",yylineno,$1); /* printf("AND\n");*/}

;

sel
    : ';'
    |
;

bool_expr
    : val GTR val { if(strcmp($1,"int")==0) 
						fprintf(fout,"isub\nifgt L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
					else
						fprintf(fout,"fcmpl\nifgt L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
					cmpline+=1;
				  }
    | val LSS val { if(strcmp($1,"int")==0) 
                        fprintf(fout,"isub\niflt L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    else
                        fprintf(fout,"fcmpl\niflt L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    cmpline+=1;
                  } 
    | val GEQ val { if(strcmp($1,"int")==0) 
                        fprintf(fout,"isub\nifge L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    else
                        fprintf(fout,"fcmpl\nifge L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    cmpline+=1;
                  } 
    | val LEQ val { if(strcmp($1,"int")==0) 
                        fprintf(fout,"isub\nifle L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    else
                        fprintf(fout,"fcmpl\nifle L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    cmpline+=1;
                  } 
    | val EQL val { if(strcmp($1,"int")==0) 
                        fprintf(fout,"isub\nifeq L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    else
                        fprintf(fout,"fcmpl\nifeq L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    cmpline+=1;
                  } 
    | val NEQ val { if(strcmp($1,"int")==0) 
                        fprintf(fout,"isub\nifne L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    else
                        fprintf(fout,"fcmpl\nifne L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n",cmpline*2,cmpline*2+1,cmpline*2,cmpline*2+1);
                    cmpline+=1;
                  } 
    | bool_expr OR bool_expr {fprintf(fout,"ior\n");}
    | bool_expr AND bool_expr {fprintf(fout,"iand\n");}
    | NOT bool_expr {fprintf(fout,"iconst_1\nixor\n");}
    | NOT bool1 {fprintf(fout,"iconst_1\nixor\n");}
;


assign_expr
    : IDENT ASSIGN val sel {
					if(lookup_symbol(scope,$1)==-1)
						printf("error:%d: undefined: %s\n",yylineno,$1);
                    else if(strcmp($3,"1")&&strcmp(findtype(scope,$1),$3)&&error!=1){
                    	printf("error:%d: invalid operation: ASSIGN (mismatched types %s and %s)\n",yylineno,findtype(scope,$1),$3);
						HAS_ERROR = true;
                	}
					else if(strcmp(findtype(scope,$1),"int")==0||strcmp(findtype(scope,$1),"float")==0)
                		fprintf(fout,"%cstore %d\n",findtype(scope,$1)[0],lookup_symbol(scope,$1));
            		else if(strcmp(findtype(scope,$1),"bool")==0)
                		fprintf(fout,"istore %d\n",lookup_symbol(scope,$1));
            		else
                		fprintf(fout,"astore %d\n",lookup_symbol(scope,$1));
                 }
	| IDENT '['{ fprintf(fout,"aload %d\n",lookup_symbol(scope,$1));}  val ']' ASSIGN val sel { fprintf(fout,"%castore\n",findtype(scope,$1)[0]);}
    | id2 ADD_ASSIGN val sel { fprintf(fout,"%cadd\n%cstore %d\n",$3[0],$3[0],lookup_symbol(scope,$1)); }
    | val ADD_ASSIGN id2 sel { printf("error:%d: cannot assign to %s\n",yylineno,$1);}
    | id2 SUB_ASSIGN val sel { fprintf(fout,"%csub\n%cstore %d\n",$3[0],$3[0],lookup_symbol(scope,$1));  }
    | id2 MUL_ASSIGN val sel { fprintf(fout,"%cmul\n%cstore %d\n",$3[0],$3[0],lookup_symbol(scope,$1));  }
    | id2 QUO_ASSIGN val sel { fprintf(fout,"%cdiv\n%cstore %d\n",$3[0],$3[0],lookup_symbol(scope,$1));  }
    | id2 REM_ASSIGN val sel { fprintf(fout,"irem\nistore %d\n",lookup_symbol(scope,$1));  }
    | IDENT {	if(!isfor){
					if(strcmp(findtype(scope,$1),"int")==0||strcmp(findtype(scope,$1),"float")==0)
                		fprintf(fout,"%cload %d\n",findtype(scope,$1)[0],lookup_symbol(scope,$1));
            		else if(strcmp(findtype(scope,$1),"bool")==0)
                		fprintf(fout,"iload %d\n",lookup_symbol(scope,$1));
            		else
                		fprintf(fout,"aload %d\n",lookup_symbol(scope,$1));
				}
	}
	  INC sel { 	    if(!isfor) fprintf(fout,"ldc 1%s\n%cadd\n%cstore %d\n",(findtype(scope,$1)[0]=='f')?".0":"",findtype(scope,$1)[0],findtype(scope,$1)[0],lookup_symbol(scope,$1)); 
						else{
							snprintf(ss,49,"iload %d\nldc 1%s\n%cadd\n%cstore %d\n",lookup_symbol(scope,$1),(findtype(scope,$1)[0]=='f')?".0":"",findtype(scope,$1)[0],findtype(scope,$1)[0],lookup_symbol(scope,$1));
							isfor=false;
						}
			  }
    | IDENT {
				if(!isfor){
                    if(strcmp(findtype(scope,$1),"int")==0||strcmp(findtype(scope,$1),"float")==0)
                        fprintf(fout,"%cload %d\n",findtype(scope,$1)[0],lookup_symbol(scope,$1));
                    else if(strcmp(findtype(scope,$1),"bool")==0)
                        fprintf(fout,"iload %d\n",lookup_symbol(scope,$1));
                    else
                        fprintf(fout,"aload %d\n",lookup_symbol(scope,$1));
				}
			}
	  DEC sel { 	    if(!isfor) fprintf(fout,"ldc 1%s\n%csub\n%cstore %d\n",(findtype(scope,$1)[0]=='f')?".0":"",findtype(scope,$1)[0],findtype(scope,$1)[0],lookup_symbol(scope,$1)); 
						else{
							snprintf(ss,49,"iload %d\nldc 1%s\n%csub\n%cstore %d\n",lookup_symbol(scope,$1),(findtype(scope,$1)[0]=='f')?".0":"",findtype(scope,$1)[0],findtype(scope,$1)[0],lookup_symbol(scope,$1));
							isfor=false;
						}
			  }
;

val
    : term {$$=$1;}
    | val '+' term sel {
                if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)==0)
                    $$=$1;
                else if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)){
                    printf("error:%d: invalid operation: ADD (mismatched types %s and %s)\n",yylineno,$1,$3);
					HAS_ERROR = true;
                    $$="1";}
                else
                    $$="1";
                fprintf(fout,"%cadd\n",$3[0]);} 
    | val '-' term sel {
                if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)==0)
                    $$=$1;
                else if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)){
                    printf("error:%d: invalid operation: SUB (mismatched types %s and %s)\n",yylineno,$1,$3);
					HAS_ERROR = true;
                    $$="1";}
                else
                    $$="1";
                fprintf(fout,"%csub\n",$3[0]);}
;

term 
    : unary {$$=$1;}
    | term '*' unary sel {
                if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)==0)
                    $$=$1;
                else if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)){
					HAS_ERROR = true;
                    printf("error:%d: invalid operation: MUL (mismatched types %s and %s)\n",yylineno,$1,$3);
                    $$="1";}
                else
                    $$="1";
                fprintf(fout,"%cmul\n",$3[0]);}
    | term '/' unary sel {
                if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)==0)
                    $$=$1;
                else if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)){
					HAS_ERROR = true;
                    printf("error:%d: invalid operation: QUO (mismatched types %s and %s)\n",yylineno,$1,$3);
                    $$="1";}
                else
                    $$="1";
                fprintf(fout,"%cdiv\n",$3[0]);}
    | term '%' unary sel {
                if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)==0)
                    $$=$1;
                else if(strcmp($1,"1")&&strcmp($3,"1")&&strcmp($1,$3)&&(strcmp($1,"float")==0||strcmp($3,"float")==0)){
					HAS_ERROR = true;
                    printf("error:%d: invalid operation: (operator REM not defined on float)\n",yylineno);
                    $$="1";}
                else
                    $$="1";
                fprintf(fout,"irem\n");}
;
unary
    : Literal { /*if(strcmp(findtype(scope,$1),"none")==0&&strcmp($1,"int")&&strcmp($1,"float")&&strcmp($1,"string")&&strcmp($1,"1"))
                    printf("error:%d: undefined: %s\n",yylineno,$1);*/
                if(strcmp($1,"1"))
                    $$=$1;
                else
                    $$="1";
                } 
    | '-' unary %prec NEG {
                if(strcmp($2,"1"))
                    $$=$2;
                else
                    $$="1";
                fprintf(fout,"%cneg\n",$2[0]); }
    | '+' unary %prec POS {
                if(strcmp($2,"1"))
                    $$=$2;
                else
                    $$="1";
                }
;

declstmt
    : type IDENT ';' {  flag=0; insert_symbol(scope,$2,$1,yylineno,"-");
						if(strcmp($1,"int")==0||strcmp($1,"float")==0)
                			fprintf(fout,"ldc 0%s\n%cstore %d\n",($1[0]=='f')?".0":"",$1[0],lookup_symbol(scope,$2));
            			else if(strcmp($1,"bool")==0)
                			fprintf(fout,"iconst_0\nistore %d\n",lookup_symbol(scope,$2));
            			else
                			fprintf(fout,"ldc \"\"\nastore %d\n",lookup_symbol(scope,$2)); 
					 }
    | type IDENT ASSIGN Literal ';' {   flag=0;  insert_symbol(scope,$2,$1,yylineno,"-"); 
										if(strcmp($1,"int")==0||strcmp($1,"float")==0)
											fprintf(fout,"%cstore %d\n",$1[0],lookup_symbol(scope,$2));
                        				else if(strcmp($1,"bool")==0)
                            				fprintf(fout,"istore %d\n",lookup_symbol(scope,$2));
                        				else
                            				fprintf(fout,"astore %d\n",lookup_symbol(scope,$2));
									}
    | type IDENT '[' val ']' ';' { flag=0; insert_symbol(scope,$2,"array",yylineno,$1); fprintf(fout,"newarray %s\n",$1); fprintf(fout,"astore %d\n",lookup_symbol(scope,$2)); }
    | type IDENT '[' val ']' ASSIGN Literal ';' { flag=0; insert_symbol(scope,$2,"array",yylineno,$1);}
;
  LB
    : '{' {++scope;}
;

Block
    : LB stmts '}' { dump_symbol(scope);
                    --scope;} 
;

IfStmt
	: IF '(' bool_expr ')' { fprintf(fout,"ifeq L_if_%d\n",ifline); ifstack[ifline]=ifline; ++ifline; } if2 
	| IF '(' val ')' { HAS_ERROR = true; printf("error:%d: non-bool (type %s) used as for condition\n",yylineno+1,$3);}
;

if2
    : Block ELSE {int p= pop2(); fprintf(fout,"goto L_if_exit%d\nL_if_%d:\n",scope,ifline-1);} elsestmt
	| Block { 	int p= pop2(); 
				fprintf(fout,"goto L_if_exit%d\nL_if_%d:\nL_if_exit%d:\n",scope,p,scope); 
			}
;

elsestmt
	: block2 { fprintf(fout,"L_if_exit%d:\n",scope); }
;

block2
	: IfStmt
	| Block
;

while2
	: WHILE {   int i=0;
				fprintf(fout,"L_for_%d:\n",forline);
				for(i=0;i<5;i++){
					if(forstack[i]==-1){ 
			    		forstack[i]=forline;
						break;
					}
				} 
				++forline;
			}
;

LoopStmt
    : FOR '(' assign_expr  {
								isfor=true;
								int i=0; 
								fprintf(fout,"L_for_%d:\n",forline);
								for(i=0;i<5;i++){
                 					if(forstack[i]==-1){ 
                     					forstack[i]=forline;
                     					break;
                 					}
             					}
            				    ++forline; 
		 					} 
	  bool_expr ';' assign_expr ')' { fprintf(fout,"ifeq L_for_exit%d\n",forline-1);}
	  Block { int p=pop(); fprintf(fout,"%s\ngoto L_for_%d\nL_for_exit%d:\n",ss,p,p); }
    | while2  '(' bool_expr ')' { fprintf(fout,"ifeq L_for_exit%d\n",forline-1);  } 
	  Block { int p=pop(); fprintf(fout,"goto L_for_%d\nL_for_exit%d:\n",p,p); }
    | while2 '(' val ')'  { HAS_ERROR = true; printf("error:%d: non-bool (type %s) used as for condition\n",yylineno+1,$3);}
;

PrintStmt
    : PRINT '(' val ')' ';' { print_val($3);}
    | PRINT '(' bool_expr ')' ';' { print_val("bool");}
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    create_symbol();
    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    codegen(".source hw3.j\n");
    codegen(".class public Main\n");
    codegen(".super java/lang/Object\n");
    codegen(".method public static main([Ljava/lang/String;)V\n");
    codegen(".limit stack 100\n");
    codegen(".limit locals 100\n");
    INDENT++;

    yyparse();
//	if(HAS_ERROR)
//		printf("Total lines: %d\n", yylineno);

    /* Codegen end */
    codegen("return\n");
    INDENT--;
    codegen(".end method\n");
    fclose(fout);
    fclose(yyin);

    if (HAS_ERROR) {
        remove(bytecode_filename);
    }
    return 0;
}

void create_symbol(){
    int i=0,j=0;
    for(i=0;i<5;i++){
        for(j=0;j<5;j++){
            s[i][j].open=false;
            s[i][j].type="";
            s[i][j].name="";
            s[i][j].et="-";
            s[i][j].addr=0;
            s[i][j].line=0;
        }
		forstack[i]=-1;
		ifstack[i]=-1;
    }
}
void insert_symbol(int scope,char*name,char*type,int line,char*et){
    int i=0;
    for(i=0;i<5;i++){
        if(!s[scope][i].open){
            s[scope][i].open = true;
            s[scope][i].name = name;
            s[scope][i].type = type;
            s[scope][i].line = line;
            s[scope][i].addr = addr;
            s[scope][i].et = et;
            break;
        }else if(flag!=1&&strcmp(s[scope][i].name,name)==0&&strcmp(et,"-")==0){
            printf("error:%d: %s redeclared in this block. previous declaration at line %d\n",yylineno,name,s[scope][i].line);
            break;
        }
    }
    addr+=1;
    flag=0;
}
int lookup_symbol(int scope,char*name){
    int i=0,j=0,tmp=-1;
    for(i=0;i<=scope;i++){
        for(j=0;j<5;j++){
            if(s[i][j].open&& strcmp(s[i][j].name,name)==0)
                tmp = s[i][j].addr;
        }
    }

    return tmp;
}

void dump_symbol(int scope){
//clear
	int i = 0;
    for(i=0;i<5;i++){
        if(s[scope][i].open){
            s[scope][i].open=false;
            s[scope][i].type="";
            s[scope][i].name="";
            s[scope][i].et="-";
            s[scope][i].addr=0;
            s[scope][i].line=0;
        }
	}
}

char* findtype(int scope,char*name){
    int i=0,j=0;
    char*tmp="none";
    for(i=0;i<=scope;i++){
        for(j=0;j<5;j++){
            if(s[i][j].open&& strcmp(s[i][j].name,name)==0&&strcmp(s[i][j].et,"-")==0)
                tmp = s[i][j].type;
            else if(s[i][j].open&& strcmp(s[i][j].name,name)==0&&strcmp(s[i][j].type,"array")==0)
                tmp = s[i][j].et;
        }
    }
    return tmp;
}  

void print_val(char*type){
	if(strcmp(type,"int")==0)
		fprintf(fout,"getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(I)V\n");
	else if(strcmp(type,"float")==0)
		fprintf(fout,"getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(F)V\n");
	else if(strcmp(type,"string")==0)
		fprintf(fout,"getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
	else{
		fprintf(fout,"ifne L_pbool_%d\n",boolline*2);
		fprintf(fout,"ldc \"false\"\ngoto L_pbool_%d\n",boolline*2+1);
		fprintf(fout,"L_pbool_%d:\nldc \"true\"\n",boolline*2);
		fprintf(fout,"L_pbool_%d:\ngetstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n",boolline*2+1);
		boolline+=1;
	}
}

int pop(){
	int i=0,j=0;
	for(i=0;i<5;i++){
		if(forstack[i]==-1&&i-1>=0){
			j=forstack[i-1];
			forstack[i-1]=-1;
			return j;
		}
	}
	return -1;
}

int pop2(){
    int i=0;
    for(i=0;i<5;i++){
        if(ifstack[i]==-1&&i-1>=0){
            ifstack[i-1]=-1;
            return i-1;
        }
    }   
    return -1; 
}

