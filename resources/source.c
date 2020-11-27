struct wibble
{ 
    int a;
} wibbles;

int main()
{

    int foo = 0;
    int bar = 1;

    struct wibble wobblers;

    wobblers.a = 10;

    struct wibble * hi = &wobblers;

    printf("%i", hi->a);

    unsigned char wibble;

    if ( foo = bar )
    {
        int given = 10;
        unsigned int stGeorge = 0xDEADBEEF;
    }

    printf(foo);

    return 0;

}

char horse(int donkey)
{
    int fourteen = 15;

    if (donkey > 10)
    {
        return donkey - 10;
    }

    return donkey+10-fourteen;
}

char * nonsense()
{
    char * p;
    p = 0x100;

    return p>>10;
}

