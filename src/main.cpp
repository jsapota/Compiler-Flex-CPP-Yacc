#include <common.h>

int compile(const char *, const char *);

/*
    argv[1] = input file
    argv[2] = output file
*/

/* TODO: Dorobic jakis help i opis uzycia */

void usage(void)
{
    std :: cout << "KOMPILATOR" << std :: endl
                << "./compiler.out inputfile outputfile" << std :: endl;
}

int main(int argc, char **argv)
{
    if(argc < 3 )
    {
        usage();
        return 0;
    }

    if( compile(argv[1], argv[2]) )
        return 1;

    return 0;
}
