# Ceres C compiler

Ceres C compiler is a C compiler written in the D programming language.

The goal of the compiler is to be able to compile C99 and target the [WDC 65C816](https://en.wikipedia.org/wiki/WDC_65C816)
micro-processor. Although, the wider goal is to support a range of old, simple,
micro-processors, including the Motorola 6502 and perhaps Z80.

## Requirements

 * Dub
 * A D compiler ( dmd, gdc, ldc )

## Building the Ceres C compiler

Currently there is a test build mode available only.

    $ dub build --config=integrationTest

Running the resulting binary will try to lex an example C file in the resources directory

Or you can build the unittests

    $ dub build --build=unittest

