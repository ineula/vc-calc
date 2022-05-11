# vc
`vc` is a console-based RPN vector calculator, implemented in a single self-contained Perl script. 
The following is based on the built-in help obtained by running `vc` with the flag `--help`.

## Overview
`vc` is an RPN calculator that supports multi-dimensional
vector arithmetic.

Each input line can be one of the following:

1) a constant:
  specified as a set of one or more comma- or space-separated
  floating-point numbers.

  e.g.
```
  1 2 3

    0> 1 2 3
```

2) a variable:
  specified by its user-assigned name.

  e.g.

```
    0> 1 2 3

  =a

    0> 1 2 3

  a

    1> 1 2 3
    0> 1 2 3
```

3) an operator:
  either a built-in or user-defined function.

  e.g.

```
    1> 1 2 3
    0> 4 5 6

  .

    0> 32
```

4) a sequence:
  a mix of the above, separated by spaces or commas; note that any
  constants will be interpreted as scalars if separated by spaces
  and vectors if separated by commas

  e.g.

```
  1 2 3 4 +

    2> 1
    1> 2
    0> 7


  1,2 3,4 +

    0> 4 6
```

## Syntax

The following is a list of `vc`'s built-in operators.
Some operators have synonyms, which are shown in braces {}.
Some operators take a numeric argument; we represent this
in the table with the metacharacter #.
Other operator arguments are enclosed in metacharacters <>.

### General Control
```
h         Print this message { ? help }
prompt    Toggle prompt on and off
q         Quit {quit exit <ctrl-D> }
u         Undo last operation; more precisely, undo the
          last change to the stack  { undo }
U         Reverse last undo { redo }
rows#     Show this many rows of stack
```

### Stack Operators
```
[return]  Duplicate last item (equivalent to c0)
ddd...    Drop last item for each "d"
d#        Drop item(s) specified, e.g. d2, d3-5
da        Drop all items; clear stack
s         Swap last two items
rrr...    Rotate stack down for each r
r#        Rotate stack down specified number of times
RRR...    Rotate stack up for each R
R#        Rotate stack up specified number of times
ccc...    Copy last item for each "c"
c#        Copy item specified to end of stack, e.g. c3
c#-#      Copy items specified to end of stack;
          e.g. c4-8 copies items 4 through 8
          e.g. c8-4 copies items 4 through 8 in reverse order
rev       Reverse stack
sort      Sort stack by vector norm of each element
count     Compute number of items in stack (does not consume stack)
><file>   Export contents of stack to file <file>; e.g. >stack
<<file>   Push contents of file <file> to stack; e.g. <stack
```

### Math Operators
```
+         Add last two items
++        Add all items
-         Subtract last item from second-last item
*         Multiply last two items
**        Multiply all items
^         Raise second-last item to power of last item { pow }
/         Divide second-last item by last
.         Compute dot product of last two items { dot }
x         Compute cross product of last two items; dims of both
          must be 3 { cross }
n         Compute vector norm of last item { norm || }
unit      Normalize last item, i.e. it turn into a unit vector
ang       Compute vector angle between last two items { angle }
proj      Compute projection of second last item onto last
trin      Compute normal of triangle whose vertex positions are
          defined in CCW order by last 3 stack items
rec       Compute reciprocal of each element in last item
sqrt      Compute square root of each element in last item
deg       Use degrees for trig functions (default)
rad       Use radians for trig functions
sin       Compute sine of each element in last item
cos       Compute cosine of each element in last item
tan       Compute tangent of each element in last item
pi        Push pi on the stack
asin      Compute inverse sine of each element in last item
acos      Compute inverse cosine of each element in last item
atan      Compute inverse tangent of each element in last item
log       Compute natural log of each element in last item
exp       Compute e raised to power of each element in last item
sinh      Compute hyperbolic sine of each element in last item
cosh      Compute hyperbolic cosine of each element in last item
tanh      Compute hyperbolic tangent of each element in last item
asinh     Compute inverse hyp sine of each element in last item
acosh     Compute inverse hyp cosine of each element in last item
atanh     Compute inverse hyp tangent of each element in last item
rand#     Push vector of # dimensions with each element a random
          value in [0,1). E.g. rand3
```

### Special Operators
```
!!!...    Repeat last input line for each !
!#        Repeat last input line the specified number of times
e#,#,...  Extract specified components from last item, e.g. e1,3,4
split     Split vector into set of component scalars {spl}
cat#      Concatenate items in last n items into a single vector.
          If no number is given, assume n=2; if n=0 concatenate all.
cat*      Concatenate all entries. {cat0}
<op>l     Apply specified two-argument operation to each item but last,
          using the last item as the second argument; <op> may be
          one of (+ - * / ^); e.g. -l subtracts the last item from
          every other item { <op>last }
clear     Clear all memory: stack, undo, user-defined variables
          and functions {cl}
```

### Variable Operators
```
=<var>   Assign last item to variable <var>. Does not consume
         last item. e.g. =a
-><var>  Assign last item to variable <var>. Consumes last item.
         e.g. ->a
#=<var>  Assign specified item to variable <var>. Does not consume.
#-><var> Assign specified item to variable <var>. Consumes.
~<var>   Clear variable <var> from memory; no effect on stack
vars     Print list of defined variables
```

### Function Operators
```
funcs    Print list of defined functions
~<func>  Clear function <func> from memory; no effect on stack

<func> = <operators>              [ see below ]
<func>(<x>,<y>,...) = <operators> [ see below ]
```

This creates the user defined function <func>, with or without
parameters. Parameters, if any, are consumed from the stack.
Parameters will not clash with user variables. To define local
variables, which do not clash with any other variables,
prefix them with an underscore (e.g. example 7).

Functions that do not have formal parameters may still access
implicit parameters on the stack (e.g. examples 2,4,6).

Functions may call one another but not recursively.

#### Example User-Defined Functions

1.  `midpoint(a,b) = a b + 2 /`
2.  `midpoint = + 2 /`
3.  `distance(x,y) = x y - n`
4.  `distance = - n`
5.  `percentChange(from,to) = to from / 1 -`
6.  `percentChange = swap / 1 -`
7.  `avg = count ->_sum ++ _sum /`


