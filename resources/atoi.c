int atoi_single(const char s)
{
    if ((s | 0xCF) == 0xFF)
    {
        return s & 0xCF;
    }
    else
        return 0;
}

const char tests_char[] = {'1', '2', '9'};
const int tests_char_count = sizeof(tests_char)/sizeof(tests_char[0]);
const int tests_char_results[] = {1,2,9};


int atoi(const char *s)
{
    int ret = 0;
    int i = 0; 
    int len = strlen(s);

    int zeros = 0;

    while (s[i])
    {
        int val = atoi_single(s[i]);

        if (val == 0 && s[i] == '0')
        {
            zeros++;
            i++;
            continue;
        }

        if (s[i] != '0' && val == 0 && s[i-1]) 
        {
            if (s[i] == ' ') {
                if (!zeros && !ret)
                {
                    i++; 
                    continue;
                }
            }

            if ( !len && s[i] )
                return ret;

            ret = ret/(int)pow(10, len-i);
            break;
        }

        int multiplier = pow(10, (len-i-1));
        ret = ret+(val * multiplier);

        i++;
    }

    return ret;
}


const char * tests[] = {"10", "56", "65", "6432","2000", "10 hello", "hello", "!!?????", "    10", "      ", "00010", "000  255", "aa56aa", "!!64", "2147483647", "4560 hell"};
const int tests_count = sizeof(tests)/sizeof(tests[0]);
const int tests_results[] = {10,56,65, 6432, 2000, 10, 0, 0, 10, 0, 10, 0, 0, 0, INT_MAX, 4560};


int main()
{
    assert(tests_count == sizeof(tests_results)/sizeof(tests_results[0]));
    assert(tests_char_count == sizeof(tests_char_results)/sizeof(tests_char_results[0]));

    int passed = 0;
    for (int i=0; i<tests_char_count;i++)
    {
        if(atoi_single(tests_char[i]) == tests_char_results[i])
            passed++;
        else
            printf("Test %i failed, result was %i\n", i, atoi_single(tests_char[i]));
    }

    for (int i=0; i<tests_count;i++)
    {
        if(atoi(tests[i]) == tests_results[i])
            passed++;
        else
            printf("Test %i failed, input '%s',  expected %i, result was %i\n", i, tests[i], tests_results[i], atoi(tests[i]));
    }

    printf("Passed %i, failed %i", passed, tests_char_count+tests_count-passed);

    if (tests_char_count+tests_count-passed)
        return 1;
    else
        return 0;
}
