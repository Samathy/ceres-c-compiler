size_t strlen(const char *s)
{
    int i = 0;
    while(s[i])
    {
        i++;
    }

    return i;
} 


char * tests[] = {"hello world", "hello world\n", "", "\0", "\0helloworld", "hello world\0", "1"};
int test_results[] = {11,12,0,0,0, 11, 1};
int tests_count = 7;


int main()
{
    int passed = 0;
    for (int i =0 ; i< tests_count; i++)
    {
        if (strlen(tests[i]) == test_results[i])
            passed++;
        else
            printf("Failed %i\n", i);
    }

    char * s = malloc(12);
    strncpy(s, "hello world\0",12);
    if ( strlen(s) == 11)
        passed++;

    printf("Passed %i, failed %i", passed, tests_count+1-passed);

    if (tests_count+1-passed)
        return 1;
    else
        return 0;

}
