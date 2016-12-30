#include "../include/common.h"

int yyparse(void);

int main(int argc, char **argv)
{
    if( yyparse() )
        return 1;

    return 0;
}
