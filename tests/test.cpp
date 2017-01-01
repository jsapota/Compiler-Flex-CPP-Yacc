/*
    Simple framework to test compiler

    Author: Michal Kukowski
    email: michalkukowski10@gmail.com

    TEST

    Test description included in test name

    PARAMS
    NO PARAMS

    RETURN:
    %PASSED iff passed
    %FAILED iff failed
*/

#include <cstdlib>
#include <cstdio>

/* ESCAPE COLORS */
#define RESET           "\033[0m"
#define RED             "\033[31m"
#define GREEN           "\033[32m"


#define PASSED 0
#define FAILED 1

#define TEST(func) \
    do{ \
        if(func) \
            printf("[TEST]\t%s\t%sFAILED%s\n", #func, RED, RESET); \
        else \
            printf("[TEST]\t%s\t%sPASSED%s\n", #func, GREEN, RESET); \
    }while(0)


static int test_gramma(void);
static int test_semantic(void);

/*
    run all tests
*/
static void run(void);


static int test_gramma()
{
    int err = 0;

    err += !!system( "./compiler.out < ./tests/gramma_errors/err1 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err2 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err3 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err4 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err5 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err6 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err7 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err8 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err9 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err10 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err11 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err12 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err13 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err14 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/gramma_errors/err15 >/dev/null 2>&1");

    return err == 15 ? PASSED : FAILED;
}

static int test_semantic()
{
    int err = 0;

    err += !!system( "./compiler.out < ./tests/semantic_errors/err1 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err2 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err3 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err4 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err5 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err6 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err7 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err8 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err9 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err10 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err11 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err12 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err13 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err14 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err15 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err16 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err17 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err18 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err19 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err20 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err21 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err22 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err23 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err24 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err25 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err26 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err27 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err28 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err29 >/dev/null 2>&1");
    err += !!system( "./compiler.out < ./tests/semantic_errors/err30 >/dev/null 2>&1");

    return err == 30 ? PASSED : FAILED;
}

static void run(void)
{
    TEST(test_gramma());
    TEST(test_semantic());
}

int main(int argc, char **agrv)
{
    run();

    return 0;
}
