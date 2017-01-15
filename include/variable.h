#ifndef VARIABLE_H
#define VARIABLE_H

#include <common.h>

/* Definision of variable structure and inline functions */

typedef struct Variable
{

    std :: string name;

    int reg;
    //zmienilem zakres addresu
    cln :: cl_I addr;
    //zmienilem zakres tablicy
    cln :: cl_I len;
    //zakres wartosci
    uint64_t val;

    bool isNum;
    bool upToDate;
    bool array;
    bool init;
    bool iter;


    uint64_t offset; /* t[1000] := a + b   offset = 1000 */
    struct Variable *varOffset; /*  t[b] := a + c  varOffset = ptr --> b*/

}Variable;

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


#endif
