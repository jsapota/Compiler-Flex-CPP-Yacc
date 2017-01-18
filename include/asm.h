#ifndef ASM_H
#define ASM_H

#include <string>
#include <vector>
#include <variable.h>

/* definision of assembler function  ( program --> asm code  ) */

extern std :: vector <std :: string> code;
extern uint64_t asmline;

inline void writeAsm(std :: string const &str)
{
    //std :: string strNew = "Line" + std :: to_string(asmline) + "-" + str;
    //code.push_back(strNew);
    code.push_back(str);
    ++asmline;
}

inline void pomp(int numRegister, uint64_t val)
{
    int i;
    writeAsm("ZERO " + std :: to_string(numRegister) + "\n");
    for(i = (sizeof(uint64_t) * 8) - 1; i > 0; --i)
        if(GET_BIT(val , i) )
            break;

    for(; i > 0; --i)
        if( GET_BIT(val , i) )
        {
            writeAsm("INC " + std :: to_string(numRegister) + "\n");
            writeAsm("SHL " + std :: to_string(numRegister) + "\n");
        }
        else
        {
            writeAsm("SHL " + std :: to_string(numRegister) + "\n");
        }

    if(GET_BIT(val, i))
        writeAsm("INC " + std :: to_string(numRegister) + "\n");
}

inline void pompBigValue(int numRegister,cln :: cl_I value)
{
    cln :: cl_I i = value;
    writeAsm("ZERO " + std :: to_string(numRegister) + "\n");
    for(i = cln :: integer_length(i); i > 0; --i){
        if(GET_BIGBIT(value , i))
            break;
    }

    for(; i > 0; --i)
        if(GET_BIGBIT(value , i))
        {
            writeAsm("INC " + std :: to_string(numRegister) + "\n");
            writeAsm("SHL " + std :: to_string(numRegister) + "\n");
        }
        else
        {
            writeAsm("SHL " + std :: to_string(numRegister) + "\n");
        }

    if(GET_BIGBIT(value, i))
        writeAsm("INC " + std :: to_string(numRegister) + "\n");
}

inline void pomp_addr(int numRegister,Variable const &var)
{
    writeAsm("ZERO " + std :: to_string(numRegister) + "\n");
    if(!var.array)
        pompBigValue(numRegister, var.addr);
    else
        if ( var.varOffset == NULL )
            pompBigValue(numRegister, var.addr + var.offset);
        else{
            pompBigValue(4,var.addr);
            pompBigValue(0,var.varOffset->addr);
            writeAsm("ADD 4 \n");
            writeAsm("COPY 4\n");
        }
}

#endif
