#!/usr/bin/perl -w

# vc: An interactive RPN vector calculator.
# (C) 2002 by Ivan Neulander <ineula@gmail.com>

use Getopt::Long;
use strict;
use vars qw($_versionString $_usageString $_useDeg
            $_pi $_radToDeg $_degToRad %_errTab);

my $VERSION = "3.1.6";
$_versionString = "vc $VERSION: An interactive RPN vector calculator.\n" .
                  "(C) 2002 by Ivan Neulander <ineula\@gmail.com>\n";

$_usageString = "vc [-help] [-version]\n";


%_errTab = (''             => 'No errors',
	   'too_few'       => 'Too few items in stack',
	   'no_match'      => 'No match',
	   'incompat_dims' => 'Incompatible dimensions',
	   'div_zero'      => 'Division by zero',
	   'invalid_tok'   => 'Invalid token',
	   'undo'          => 'No more undo',
	   'redo'          => 'No more redo',
	   'file_write'    => 'Cannot write stack to file',
	   'file_read'     => 'Cannot read stack from file',
	   'illegal'       => 'Illegal value for operation');

$_useDeg = 1;
$_pi = 4*atan2(1,1);
$_radToDeg = 180/$_pi;
$_degToRad = $_pi/180;

sub tan($)  { my $x = shift; return sin($x)/cos($x); }

sub sinh($) { my $x = shift; return .5*(exp($x) - exp(-$x)); }
sub cosh($) { my $x = shift; return .5*(exp($x) + exp(-$x)); }
sub tanh($) { my $x = shift; return sinh($x)/cosh($x); }

sub asin($) { my $x = shift; return atan2($x, sqrt(1 - $x*$x)); }
sub acos($) { my $x = shift; return atan2(sqrt(1 - $x*$x), $x); }

sub asinh($) { my $x = shift; return log($x + sqrt($x*$x + 1)); }
sub acosh($) { my $x = shift; return log($x + sqrt($x*$x - 1)); }
sub atanh($) { my $x = shift; return .5*log((1 + $x) / (1 - $x)); }

sub __sin($) {
  $_useDeg ? 
    sin($_degToRad*shift) : sin(shift);
}

sub __cos($) {
  $_useDeg ? 
    cos($_degToRad*shift) : cos(shift);
}

sub __tan($) {
  $_useDeg ? 
    tan($_degToRad*shift) : tan(shift);
}

sub __asin($) {
  $_useDeg ? 
    $_radToDeg*asin(shift) : asin(shift);
}

sub __acos($) {
  $_useDeg ? 
    $_radToDeg*acos(shift) : acos(shift);
}

sub __atan($) {
  $_useDeg ? 
    $_radToDeg*atan2(shift,1) : atan2(shift,1);
}

sub main() {
  my ($help, $version);

  if (@ARGV>0 && $ARGV[0] eq '--') {
    print $_usageString;
    exit 0;
  }

  unless (GetOptions('help'    => \$help,
		     'version' => \$version)) {
    print $_usageString;
    exit 1;
  }

  if ($version) {
    print $_versionString;
    exit 0;
  }

  if ($help) {
    printHelp();
    exit 0;
  }

  calcLoop();
  return 0;
}

sub calcLoop() {
  my $stack = [];
  my @stackCopies = ([]);
  my $stackIndex = 0;
  my $err = 0;
  my $copyStack = 0;
  my $lastCmd;
  my $doLast = 0;
  my $prompt = 1;
  my $rows = ($ENV{ROWS} || 25) - 3;
  my %func = ();
  my %var = ();

 MAINLOOP:
  while (<>) {
    chomp;
    s/[{}[\]]+//g;
    s/^[,\s]+//;

    $err = '';
    $copyStack = 1;

    # repeat last command
    if (/^(\!+)$/) {
      $doLast = length $1;
    } elsif (/^\!(\d+)/) {
      $doLast = $1;
    }

    if ($doLast && defined $lastCmd) {
      $_ = ($lastCmd . " ") x $doLast;
    } else {
      $lastCmd = $_;
    }

    if ($_ eq '') {
      # dup last stack item
      $err = _copyLast($stack, 1);
      next MAINLOOP;
    }

    # try to parse a vector entry

  VECPARSE: {
      my $lineCopy = $_;
      $lineCopy =~ s/[()]//g;
      $lineCopy =~ s/^\s+//g;
      my @nums = split /[\s,]+/, $lineCopy;
      for (@nums) {
	last VECPARSE unless _isFloat($_);
	$_ += 0;
      }
      # succeeded
      _appendVec($stack, \@nums);
      next MAINLOOP;
    }

    # try to parse function definition
    if (/^([A-Za-z]\w*)\s*=\s*(.*)$/) {
      $func{$1}[0] = [];
      $func{$1}[1] = $2;
      next MAINLOOP;
    }

    # 2) with args
    if (/^([A-Za-z]\w*)\s*\(([\w,]*)\)\s*=\s*(.*)$/) {
      $func{$1}[0] = [split /[\s,]/, $2];
      $func{$1}[1] = $3;
      next MAINLOOP;
    }

    # try to parse a function call
    my @preCmds = split /[\s]/, $_;
    my @cmds = ();
    my %resolved = ();

    while(1) {
      my $found;
      for (@preCmds) {
	my $funcName = $_;
	my $prog = $func{$funcName};
	if ($prog) {
	  my $funcCode = $prog->[1];

	  # prepend function name to any variables starting
	  # with _.
	  $funcCode =~ s/(^|\W)(_\w+)/$1_$funcName$2/g;

	  if ($prog->[0]) {
	    # setup args
	    for (reverse @{$prog->[0]}) {
	      my $argName = "_${funcName}_$_";
	      push @cmds, "->$argName";
	      $funcCode =~ s/$_(\s|$)/$argName$1/g;
	    }
	  }
	  push @cmds, split /\s/,$funcCode;
	  $found = $prog;
	} else {
	  push @cmds, $_;
	}
      }
      last unless $found;
      if ($resolved{$found}) {
	print "(circular reference in '$found->[1]')\n";
	next MAINLOOP;
      }
      @preCmds = @cmds;
      @cmds = ();
      $resolved{$found} = 1;
    }

  CMDLOOP:
    for (@cmds) {
      $copyStack = 1;
      $err = '';
      {
	# check for embedded vector
	my @vec = ();
	for (split /,/,$_) {
	  if (_isFloat($_)) {
	    push @vec, $_ + 0;
	  } else {
	    @vec = ();
	    last;
	  }
	}
	if (@vec) {
	  _appendVec($stack, \@vec);
	  next CMDLOOP;
	}
      }

      if (_isFloat($_)) {
	_appendVec($stack, [$_]);
      } elsif (/^(\d+)=(\w+)$/) { # assign nondestructive #
	if ($1 >= @$stack) {
	  $err = 'too_few';
	} else {
	  $var{$2} = $stack->[$1];
	}
	$copyStack = 0;
      } elsif (/^=(\w+)$/) { # assign nondestructive last
	if (@$stack) {
	  $var{$1} = $stack->[0];
	} else {
	  $err = 'too_few';
	}
	$copyStack = 0;
      } elsif (/^(\d+)->(\w+)$/) { # assign destructive #
	if ($1 >= @$stack) {
	  $err = 'too_few';
	} else {
	  $var{$2} = $stack->[$1];
	  _drop($stack, $1, $1);
	}
      } elsif (/^->(\w+)$/) { # assign destructive last
	if (@$stack) {
	  $var{$1} = shift @$stack;
	} else {
	  $err = 'too_few';
	}
      } elsif (/^(\w+)$/ && $var{$1}) {
	unshift @$stack, $var{$1};
      } elsif (/^vars$/) { # print user variables
	for (keys %var) {
	  next if /^_/;
	  print "  $_ = @{$var{$_}}\n";
	}
	$copyStack = 0;
      } elsif (/^funcs$/) { # print user functions
	for (keys %func) {
	  my $par = join ", ", @{$func{$_}[0]};
	  print "  $_($par) = $func{$_}[1]\n";
	}
	$copyStack = 0;
      } elsif (/^~(\w+)$/) { # clear func or var
	delete $var{$1};
	delete $func{$1};
	$copyStack = 0;
      } elsif (/^cl(?:ear)?$/) { # clear all
	@$stack = ();
	@stackCopies = ([]);
	$stackIndex = 0;
	$copyStack = 0;
	%var = ();
	%func = ();
      } elsif (/^>(.*)/) { # write to file
	$copyStack = 0;
	$err = _fileWrite($stack, $1);
      } elsif (/^<(.*)/) { # read from file
	$err = _fileRead($stack, $1);
      } elsif (/^int$/) { # convert to int
	$err = _int($stack);
      } elsif (/^\+$/) { # add
	$err = _sum($stack);
      } elsif (/^\+\+$/) { # add all
	$err = _opAll($stack, \&_sum);
      } elsif (/^\+l(ast)?$/) { # add last to rest
	$err = _opLast($stack, \&_sum);
      } elsif ($_ eq '-') { # subtract
	$err = _diff($stack);
      } elsif (/^\-l(ast)?$/) { # sub last from rest
	$err = _opLast($stack, \&_diff);
      } elsif ($_ eq '*') { # multiply
	$err = _prod($stack);
      } elsif ($_ eq '**') { # multiply all
	$err = _opAll($stack, \&_prod);
      } elsif (/^\*l(ast)?$/) { #mult last with rest
	$err = _opLast($stack, \&_prod);
      } elsif (/^pow$/ or /^\^$/) { # exponentiate
	$err = _pow($stack);
      } elsif (/^powl(ast)?$/ or /^\^l(ast)?$/) { # exp last
	$err = _opLast($stack, \&_pow);
      } elsif ($_ eq '/') { # divide
	$err = _quot($stack);
      } elsif (m|^/l(ast)?$|i) { # divide rest by last
	$err = _opLast($stack, \&_quot);
      } elsif ($_ eq '.' or /^dot$/) { # dot product
	$err = _dot($stack);
      } elsif (/^x$/ or /^cross$/) { # cross product
	$err = _cross($stack);
      } elsif (/^\|\|$/ or /^n(orm)?$/) { # vector norm
	$err = _norm($stack);
      } elsif (/^unit$/) { # unit vector
	$err = _unit($stack);
      } elsif (/^sort$/) { # sort stack
	$err = _sort($stack);
      } elsif (/^ang(le)?$/) { # angle between vectors
	$err = _angle($stack);
      } elsif (/^proj$/) { # vector projection
	$err = _proj($stack); 
      } elsif (/^trin$/) { # triangle normal
	$err = _trin($stack); 
      } elsif (/^sqrt$/) { # square root
	$err = _sqrt($stack);
      } elsif (/^rec$/) { # reciprocal
	$err =_rec($stack);
      } elsif (/^sin$/) { # sin
	$err = _sin($stack);
      } elsif (/^sinh$/) { # sinh
	$err = _sinh($stack);
      } elsif (/^cos$/) { # cos
	$err = _cos($stack);
      } elsif (/^cosh$/) { # cosh
	$err = _cosh($stack);
      } elsif (/^tan$/) { # tan
	$err = _tan($stack);
      } elsif (/^tanh$/) { # tanh
	$err = _tanh($stack);
      } elsif (/^asin$/) { # asin
	$err = _asin($stack);
      } elsif (/^asinh$/) { # asinh
	$err = _asinh($stack);
      } elsif (/^acos$/) { # acos
	$err = _acos($stack);
      } elsif (/^acosh$/) { # acosh
	$err = _acosh($stack);
      } elsif (/^atan$/) { # atan
	$err = _atan($stack);
      } elsif (/^atanh$/) { # atanh
	$err = _atanh($stack);
      } elsif (/^deg$/) { # degree mode
	$_useDeg = 1;
      } elsif (/^rad$/) { # radian mode
	$_useDeg = 0;
      } elsif (/^ln$/) { # log
	$err = _ln($stack);
      } elsif (/^log$/) { # log
	$err = _log($stack);
      } elsif (/^exp$/) { # exp
	$err = _exp($stack);
      } elsif (/^e(\d+(?:,\d+)*)$/) { # extract entries
	$err = _extract($stack, $1);
      } elsif (/^spl(?:it)?$/) {
	$err = _split($stack);
      } elsif (/^s(wap)?$/) { # swap last two entries
	$err = _swap($stack);
      } elsif (/^r(\d+)$/) { # rotate stack down n times
	$err = _rot($stack, $1);
      } elsif (/^(r+)$/) { # rotate stack down n times
	$err = _rot($stack, length $1);
      } elsif (/^(R+)$/) { # rotate stack up n times
	$err = _rot($stack, -length $1);
      } elsif (/^R(\d+)$/) { # rotate stack up n times
	$err = _rot($stack, -$1);
      } elsif (/^d(\d+)-(\d+)$/) { # drop given entries
	$err = _drop($stack, $1, $2);
      } elsif (/^d(\d+)$/) { # drop given entry
	$err = _drop($stack, $1, $1);
      } elsif (/^(d+)$/) { # drop last n entries
	$err = _dropLast($stack, length $1);
      } elsif (/^da$/) { # drop all entries
	$err = _dropAll($stack);
      } elsif (/^c(\d+)-(\d+)$/) { # copy given entries
	$err = _copy($stack, $1, $2);
      } elsif (/^c(\d+)$/) { # copy given entry
	$err = _copy($stack, $1, $1);
      } elsif (/^(c+)$/) { # copy last n entries
	$err = _copyLast($stack, length $1);
      } elsif (/^count$/) { # how many elements on stack
	$err = _count($stack);
      } elsif (/^rev$/) { # reverse stack
	$err = _reverse($stack);
      } elsif (/^rand(\d+)$/) { # vector of random [0,1]
	$err = _rand($stack, $1);
      } elsif (/^rand$/) { # vector of random [0,1]
	$err = _rand($stack, 1);
      } elsif (/^pi$/) {
	$err = _pi($stack);
      } elsif (/^cat$/) { # concatenate last 2 entries
	$err = _cat($stack,2);
      } elsif (/^cat(\d+)$/) { # concatenate last n entries
	$err = _cat($stack,$1);
      } elsif (/^cat\*$/) { # concatenate all entries
	$err= _cat($stack,0);
      } elsif (/^q(uit)?$/ or /^exit$/) { # quit
	last MAINLOOP;
      } elsif (/^prompt$/) {
	$prompt = !$prompt;
      } elsif (/^rows?(\d+)$/) {
	$rows = $1;
	$rows = 0 if $rows < 0;
      } elsif (/^u$/ or /^undo$/) { # undo
	$copyStack = 0;
	if ($stackIndex <= 0) {
	  $err = 'undo';
	  next MAINLOOP;
	}
	@$stack = @{$stackCopies[--$stackIndex]};
      } elsif (/^U$/ or /^redo$/) { # redo
	$copyStack = 0;
	if ($stackIndex >= $#stackCopies) {
	  $err = 'redo';
	  next MAINLOOP;
	}
	@$stack = @{$stackCopies[++$stackIndex]};
      } elsif (/^(\?|(h(elp)?))$/) {
	$copyStack = 0;
	$err = _help();
      } else {
	$err = 'invalid_tok';
	@$stack = @{$stackCopies[$stackIndex]};
	next MAINLOOP;
      }

      if ($err) {
	next MAINLOOP;
      }
    }

  } continue {

    if ($err) {
      # restore the stack if there was an error
      @$stack = @{$stackCopies[$stackIndex]}
    }
    _showStack($stack, $prompt, $rows);

    $doLast = 0 if $doLast;

    if ($err) { 
      print "Error: $_errTab{$err}.\n"; 
    } elsif ($copyStack) {
      $stackCopies[++$stackIndex] = [@$stack];
      if ($#stackCopies > $stackIndex) {
	$#stackCopies = $stackIndex;
      }
    }
  }
}

sub _dropAll($) {
  my $s = shift;
  @$s = ();
  return '';
}


sub _drop($$$) {
  my ($s,$min,$max) = @_;
  return 'too_few' if @$s < 1;
  if ($min > $max) {
    ($min, $max) = ($max, $min);
  }
  if ($min < 0) { $min = 0; }

  my @sCopy = ();
  my $found = 0;
  for (0..$#$s) {
    if ($_ >= $min && $_ <= $max) {
      $found = 1;
    } else {
      push @sCopy, $$s[$_];
    }
  }
  return 'no_match' unless $found;
  @$s = @sCopy;
  return '';
}

sub _dropLast($$) {
  my ($s, $n) = @_;
  return _drop($s, 0, $n-1);
}

sub _swap($) {
  my $s = shift;
  return 'too_few' if @$s < 2;
  ($s->[0], $s->[1]) = ($s->[1], $s->[0]);
  return '';
}

sub _rot($$) {
  my ($s,$n) = @_;
  return 'too_few' unless @$s;
  while($n < 0) { $n += @$s; }
  for (1..$n) {
    push @$s, shift @$s;
  }
  return '';
}

sub _copyLast($$) {
  my ($s,$n) = @_;
  return _copy($s, $n - 1, 0);
}

sub _copy($$$) {
  my ($s, $from, $to) = @_;
  return 'too_few' unless @$s;
  return 'no_match' if $from < 0 or $to < 0;

  my $found = 0;
  my $max = $#$s;
  if ($from <= $to) {
    for (0..$max) {
      if ($_ >= $from && $_ <= $to) {
	unshift @$s, $s->[$_ + $found++];
      }
    }
  } else {
    for (reverse 0..$max) {
      if ($_ >= $to && $_ <= $from) {
	unshift @$s, $s->[$_ + $found++];
      }
    }
  }
  return 'no_match' unless $found;
  return '';
}

sub _sort($) {
  my $s = shift;
  my %vals;
  for (@$s) {
    my $e = $_;
    my $sum = 0;
    for (0..scalar @$e-1) {
      $sum += $e->[$_]*$e->[$_];
    }
    $vals{$e} = $sum;
  }
  @$s = sort { $vals{$b} <=> $vals{$a} } @$s;
  return '';
}

sub _norm($) {
  my $s = shift;
  return 'too_few' if @$s < 1;
  my $e = shift @$s;
  my $dim = scalar @$e;
  my $sum = 0;
  for (0..$dim-1) {
    $sum += $$e[$_] * $$e[$_];
  }
  my @result = sqrt($sum);
  unshift @$s, \@result;
  return '';
}

sub _multiOp1($$$) {
  my ($s, $op, $cond) = @_;
  return 'too_few' if @$s < 1;
  my $e = shift @$s;
  my $dim = scalar @$e;
  my @result = ();
  for (0..$dim-1) {
    my $val = $$e[$_];
    return 'illegal' unless &$cond($val);
    push @result, &$op($val);
  }
  unshift @$s, \@result;
  return '';
}

sub _multiOp2($$$) {
  my ($s, $op, $cond) = @_;
  return 'too_few' if @$s < 2;
  my ($e2, $e1) = (shift @$s, shift @$s);
  my ($dim1, $dim2) = (scalar @$e1, scalar @$e2);

  my @result = ();
  if ($dim1 == 1) {
    for (0..$dim2-1) {
      return 'illegal' unless &$cond($$e1[0], $$e2[$_]);
      $result[$_] = &$op($$e1[0], $$e2[$_]);
    }
  } elsif ($dim2 == 1) {
    for (0..$dim1-1) {
      return 'illegal' unless &$cond($$e1[$_], $$e2[0]);
      $result[$_] = &$op($$e1[$_], $$e2[0]);
    }
  } elsif ($dim1 == $dim2) {
    for (0..$dim1-1) {
      return 'illegal' unless &$cond($$e1[$_], $$e2[$_]);
      $result[$_] = &$op($$e1[$_], $$e2[$_]);
    }
  } else { 
    return 'incompat_dims';
  }

  unshift @$s, \@result;
  return '';
}

sub _opLast($$) {
  my ($s, $fun) = @_;
  return 'too_few' if @$s < 2;
  my $bottom = shift @$s;
  for (0..scalar(@$s) - 1) {
    my $err = _rot($s,1);
    return $err if $err;
    unshift @$s, $bottom;
    $err = &$fun($s);
    return $err if $err;
  }
}

sub _opAll($$) {
  my ($s, $fun) = @_;
  for (2..scalar(@$s)) {
    my $err = &$fun($s);
    return $err if $err
  }
  return '';
}

sub _sum($) {
  my $s = shift;
  return _multiOp2($s, sub {shift() + shift()}, sub {1});
}

sub _diff($) {
  my $s = shift;
  return _multiOp2($s, sub {shift()-shift()}, sub{1});
}

sub _prod($) {
  my $s = shift;
  return _multiOp2($s, sub {shift() * shift()}, sub {1});
}

sub _pow($) {
  my $s = shift;
  return _multiOp2($s, sub {shift() ** shift()},
		   sub{shift() or shift()>=0});
}

sub _quot($) {
  my $s = shift;
  return _multiOp2($s, sub {shift() / shift()}, sub {$_[1] != 0});
}

sub _dot($) {
  my $s = shift;
  return 'no_match' if @$s < 2;
  my ($e2, $e1) = (shift @$s, shift @$s);
  my ($dim1, $dim2) = (scalar @$e1, scalar @$e2);
  return 'incompat_dims' unless $dim1 == $dim2;

  my @result = (0);
  for (0..$dim1-1) {
    $result[0] += $$e1[$_] * $$e2[$_];
  }
  unshift @$s, \@result;
  return '';
}

sub _unit($) {
  my $s = shift;
  my $err = '';

  $err = _copyLast($s,1);
  return $err if $err;
  $err = _norm($s);
  return $err if $err;

  return _quot($s);
}

sub _angle($) {
  my $s = shift;
  my $err = '';

  $err = _unit($s);
  return $err if $err;
  $err = _swap($s);
  return $err if $err;
  $err = _unit($s);
  return $err if $err;
  $err = _dot($s);
  return $err if $err;

  # clamp dot to [-1,1]
  #my $e = $s->[$#$s];
  my $e = $s->[0];
  if ($$e[0] < -1) {
    $$e[0] = -1;
  } elsif ($$e[0] > 1) {
    $$e[0] = 1;
  }

  return _acos($s);
}

sub _proj($) {
  my $s = shift;
  my $err = '';

  $err = _unit($s);
  return $err if $err;
  $err = _copyLast($s,1);
  return $err if $err;
  $err = _rot($s,1);
  return $err if $err;
  $err = _dot($s);
  return $err if $err;
  $err = _rot($s,-1);

  return _prod($s);
}

sub _trin($) {
  my $s = shift;
  my $err = '';

  $err = _copyLast($s,1);
  return $err if $err;
  $err = _rot($s,1);
  return $err if $err;
  $err = _diff($s);
  return $err if $err;
  $err = _swap($s);
  return $err if $err;
  $err = _rot($s,-1);
  return $err if $err;
  $err = _diff($s);
  return $err if $err;
  $err = _swap($s);
  return $err if $err;

  return _cross($s);
}


sub _cross($) {
  my $s = shift;
  return 'too_few' if @$s < 2;
  my ($e2, $e1) = (shift @$s, shift @$s);
  my ($dim1, $dim2) = (scalar @$e1, scalar @$e2);

  my @result = (0);
  return 'incompat_dims' unless ($dim1 == 3 && $dim2== 3);

  $result[0] += $$e1[1]*$$e2[2] - $$e1[2]*$$e2[1];
  $result[1] += $$e1[2]*$$e2[0] - $$e1[0]*$$e2[2];
  $result[2] += $$e1[0]*$$e2[1] - $$e1[1]*$$e2[0];

  unshift @$s, \@result;
  return '';
}

sub _extract($$) {
  my ($s, $selection) = @_;
  return 'too_few' unless @$s > 0;
  my $vec = shift @$s;
  my @items = split /,/, $selection;
  my @result = ();
  my $dim = scalar @$vec;
  for (@items) {
    $_--;
    return 'no_match' if ($_ < 0 || $_ >= $dim);
    push @result, $vec->[$_];
  }
  unshift @$s, \@result;
  return '';
}

sub _split($) {
  my $s = shift;
  return 'too_few' unless @$s > 0;
  my $e = shift @$s;
  for (@$e) { unshift @$s, [$_]; }
  return '';
}

sub _cat($$) {
  my ($s, $n) = @_;
  $n ||= @$s;
  return 'too_few' unless @$s >= $n && @$s > 0;
  my @new = ();
  for (1..$n) { unshift @new, @{shift @$s}; }
  unshift @$s, \@new;
  return '';
}

sub _showStack($$;$) {
  my ($s,$usePrompt,$rows) = @_;
  my $num = $#$s;

  print "\n";
  print "  .....\n" if $rows && @$s > $rows;
  for (reverse @$s) {
    next if $rows && $num >= $rows;
    my $prompt = $usePrompt ? "  $num> " : '';
    print $prompt, join(' ', @$_), "\n";
  } continue {
    $num--;
  }
    print "\n";
  return '';
}

sub _sin($) {
  return _multiOp1(shift, sub {__sin shift}, sub {1});
}

sub _sinh($) {
  return _multiOp1(shift, sub {sinh shift}, sub{1});
}

sub _cos($) {
  return _multiOp1(shift, sub {__cos shift}, sub {1});
}

sub _cosh($) {
  return _multiOp1(shift, sub {cosh shift}, sub {1});
}


sub _tan($) {
  return _multiOp1(shift, sub {__tan shift}, sub {__cos(shift) != 0});
}

sub _tanh($) {
  return _multiOp1(shift, sub {tanh shift}, sub {cosh(shift) != 0});
}

sub _asin($) {
  return _multiOp1(shift, sub {__asin shift}, 
		   sub {$_[0]>=-1 && $_[0]<=1});
}

sub _acos($) {
  return _multiOp1(shift, sub {__acos shift}, 
		   sub {$_[0]>=-1 && $_[0]<=1});
}

sub _atan($) {
  return _multiOp1(shift, sub {__atan shift}, sub {1});
}

sub _asinh($) {
  return _multiOp1(shift, sub {asinh shift}, sub {1});
}

sub _acosh($) {
  return _multiOp1(shift, sub {acosh shift}, sub {shift >= 1});
}

sub _atanh($) {
  return _multiOp1(shift, sub {atanh shift}, sub {abs(shift) < 1});
}

sub _ln($) {
  return _multiOp1(shift, sub {log shift}, sub {shift > 0});
}

sub _log($) {
  return _multiOp1(shift, sub {log(shift)/log 10}, sub {shift > 0});
}

sub _exp($) {
  return _multiOp1(shift, sub {exp shift}, sub {1});
}

sub _sqrt($) {
  return _multiOp1(shift, sub {sqrt shift}, sub {shift >= 0});
}

sub _rec($) {
  return _multiOp1(shift, sub {1/shift}, sub {shift != 0});
}

sub _count($) {
  my $s = shift;
  unshift @$s, [scalar @$s];
  return '';
}

sub _reverse($) {
  my $s = shift;
  @$s = reverse @$s;
  return '';
}

sub _rand($$) {
  my ($stack,$dim) = @_;
  return '' if $dim == 0;
  my $val = [];
  for (1..$dim) { push @$val, rand; }
  unshift @$stack, $val;
  return '';
}

sub _pi($) {
  my $stack = shift;
  unshift @$stack, [$_pi];
  return '';
}

sub _appendVec($$) {
  my ($s,$v) = @_;
  unshift @$s, $v;
  return '';
}

sub _isFloat($);
sub _isFloat($) {
  my $v = shift;
  if ($v =~ /e/) {
    # handle exponential notation
    my @part = split /e/, $v;
    return 0 if @part != 2 || $part[1] =~ /\./;
    $part[0] =~ s/e//;
    $part[1] =~ s/e//;
    $part[1] =~ s/^[+-]//;
    return _isFloat($part[0]) && _isFloat($part[1]);
  }

  return 1 if $v =~ /^\s*\-?\s*(\d*)(\.?(\d*))\s*$/ and
    $1 ne '' || $3 ne '';

  return 0;
}

sub _fileWrite($$) {
  my ($stack, $fileName) = @_;
  open OUT, ">$fileName" or return 'file_write';
  for (reverse @$stack) {
    print OUT "@$_\n";
  }
  close OUT;
  return '';
}

sub _fileRead($$) {
  my ($stack, $fileName) = @_;
  open IN, "$fileName" or return 'file_read';
  for (<IN>) {
    chomp;
    my @vec = split /\s+/, $_;
    unshift @$stack, \@vec;
  }
  close IN;
  return '';
}

sub _int($) {
  my $s = shift;
  return 'too_few' if @$s < 1;
  for (@{$s->[0]}) { $_ = int $_; }
  return '';
}

sub printHelp() {
  _help();
}

sub _help() {
  my $here = <<HELP;
  $_versionString

  vc is an RPN calculator that supports multi-dimensional
  vector arithmetic.

  Each input line can be one of the following:

  1) a constant:
    specified as a set of one or more comma- or space-separated
    floating-point numbers.

    e.g.

    1 2 3

      0> 1 2 3

  2) a variable:
    specified by its user-assigned name.

    e.g.

      0> 1 2 3

    =a

      0> 1 2 3

    a

      1> 1 2 3
      0> 1 2 3

  3) an operator:
    either a built-in or user-defined function.

    e.g.

      1> 1 2 3
      0> 4 5 6

    .

      0> 32


  4) a sequence:
    a mix of the above, separated by spaces or commas; note that any
    constants will be interpreted as scalars if separated by spaces
    and vectors if separated by commas

    e.g.

    1 2 3 4 +

      2> 1
      1> 2
      0> 7


    1,2 3,4 +

      0> 4 6


  The following is a list of vc's built-in operators.
  Some operators have synonyms, which are shown in braces {}.
  Some operators take a numeric argument; we represent this
  in the table with the metacharacter #.
  Other operator arguments are enclosed in metacharacters <>.

  General Control
  ---------------
  h         Print this message { ? help }
  prompt    Toggle prompt on and off
  q         Quit {quit exit <ctrl-D> }
  u         Undo last operation; more precisely, undo the
            last change to the stack  { undo }
  U         Reverse last undo { redo }
  rows#     Show this many rows of stack

  Stack Operators
  ---------------
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


  Math Operators
  --------------
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

Special Operators
-----------------
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

Variable Operators
--------------------
  =<var>   Assign last item to variable <var>. Does not consume
           last item. e.g. =a
  -><var>  Assign last item to variable <var>. Consumes last item.
           e.g. ->a
  #=<var>  Assign specified item to variable <var>. Does not consume.
  #-><var> Assign specified item to variable <var>. Consumes.
  ~<var>   Clear variable <var> from memory; no effect on stack
  vars     Print list of defined variables


Function Operators
------------------
  funcs    Print list of defined functions
  ~<func>  Clear function <func> from memory; no effect on stack

  <func> = <operators>              [ see below ]
  <func>(<x>,<y>,...) = <operators> [ see below ]

  This creates the user defined function <func>, with or without
  parameters. Parameters, if any, are consumed from the stack.
  Parameters will not clash with user variables. To define local
  variables, which do not clash with any other variables,
  prefix them with an underscore (e.g. example 7).

  Functions that do not have formal parameters may still access
  implicit parameters on the stack (e.g. examples 2,4,6).

  Functions may call one another but not recursively.

  Example User-Defined Functions:

  1.  midpoint(a,b) = a b + 2 /
  2.  midpoint = + 2 /
  3.  distance(x,y) = x y - n
  4.  distance = - n
  5.  percentChange(from,to) = to from / 1 -
  6.  percentChange = swap / 1 -
  7.  avg = count ->_sum ++ _sum /



HELP
  $here =~ s/^  //mg;
  if (-x "/usr/bin/less" && $ENV{TERM} !~ /^dumb/i) {
    $here =~ s/'/'"'"'/g;
    system("echo '$here' | /usr/bin/less");
  } else {
    print $here;
  }
  return '';
}

exit main();

=head1 NAME

  vc: An RPN vector calculator

=head1 SYNOPSIS

  vc [-help] [-version]

=head1 DESCRIPTION

  This script implements an RPN calculator that handles vectors
  of arbitrary dimensionality. It supports various arithmetic
  operations on vectors of compatible dimensions. It also supports
  unlimited undo/redo and basic macro programmability. Run with
  -help flag for more info.

=head1 PREREQUISITES

  This script requires C<Getopt::Long>, C<strict>, C<vars>.

=head1 COPYRIGHT

  (C) 2002 by Ivan Neulander <ineula@gmail.com>

  All rights reserved. You may distribute this code under the terms
  of either the GNU General Public License or the Artistic License,
  as specified in the Perl README file.

=head1 README

  This script implements an RPN calculator that handles vectors
  of arbitrary dimensionality. It supports various arithmetic
  operations on vectors of compatible dimensions. It also supports
  unlimited undo/redo and basic macro programmability. Run with
  -help flag for more info.

=pod SCRIPT CATEGORIES

  Educational
  Scientific
  Math

=cut

