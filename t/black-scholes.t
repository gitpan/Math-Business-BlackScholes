#!perl -w

use strict;
$^W=1;
BEGIN { chdir "t" if -d "t"; }
use lib '../blib/arch', '../blib/lib';

use Test;
BEGIN { plan tests => 159, todo => [] }

use Math::Business::BlackScholes (
  qw/call_price put_price call_put_prices/,
  qw/implied_volatility_call implied_volatility_put/
);

my $tol=2e-5; # Tolerance for floating point comparisons
$Math::Business::BlackScholes::max_iter=10;

sub ae {
	my $lhs=shift;
	my $rhs=shift;
	my $ref=shift || 0.0;
# print("$lhs =? $rhs\n");
	return abs($lhs-$rhs) <= (abs($rhs) + abs($ref))*$tol;
}

sub check {
	ok(check1(@_));
}

sub check1 {
	die unless @_>=7 && @_<=9;
	my $call0=shift;
	my $put0=shift;
	my $mkt=$_[0];

	my $call1=call_price(@_);
	my $put1=put_price(@_);
	my ($call2, $put2)=call_put_prices(@_);

	ok($call1>=0);
	ok($put1>=0);

	ok(ae($call1, $call0));
	ok(ae($put1, $put0, $mkt));
	ok(ae($call2, $call1));
	ok(ae($put2, $put1));

	my $call10=call_price(10*$_[0], $_[1], 10*$_[2], @_[3..$#_]);
	ok(ae($call10, 10*$call1));

	my $put10=put_price(
	  $_[0], $_[1]/sqrt(10), $_[2], $_[3]*10, $_[4]/10, ($_[5] || 0)/10
	);
	ok(ae($put10,$put1));

	if($_[0]*$_[2]>0 && $_[3]>0) {
		my ($s, $e, $c)=implied_volatility_call(
		  $_[0], $call1, @_[2..$#_]
		);
		ok(ae($s, $_[1], 2.0*$e/$tol) && $c<10);
		ok(ae(
		  scalar implied_volatility_put($_[0], $put1, @_[2..$#_]),
		  $_[1], 2.0*$e/$tol
		));
	}
	else {
		ok(1); ok(1);
	}

	return 1;
}

sub checkwarn {
	my $w;
	local($SIG{__WARN__})=sub { $w=1; };
	check(@_);
	ok($w);
}

# Each call to check() is 11 ok()'s.
check(1.65382, 1.45777, 10, 0.4, 10, 1, 0.03, 0.01);
check(3.14596, 2.94991, 10, 0.8, 10, 1, 0.03, 0.01);
check(2.13108, 0.96459, 10, 0.4, 9, 1, 0.03, 0.01);
check(1.16364, 1.06464, 10, 0.4, 10, 0.5, 0.03, 0.01);
check(1.78436, 1.30150, 10, 0.4, 10, 1, 0.06, 0.01);
check(1.59531, 1.49778, 10, 0.4, 10, 1, 0.03, 0.02);
check(0.96459, 2.13108, -10, 0.4, -9, 1, 0.03, 0.01);

check(1.71387, 1.41833, 10, 0.4, 10, 1, 0.03, 0);
check(1.71387, 1.41833, 10, 0.4, 10, 1, 0.03);

# Each call to checkwarn() is 12 ok()'s.
checkwarn( 0, 0, 10, -0.4, 10, 0, 0.03, 0.01);
checkwarn(20, 0, 10, 0.4, -10, 0, 0.03, 0.01);
checkwarn( 0, 0, 10, 0.4, 10, 0, -0.03, 0.01);
checkwarn( 0, 0, 10, 0.4, 10, 0, 0.03, -0.01);
checkwarn(1.65382, 1.45777, 10, 0.4, 10, 1, 0.03, 0.01, 999);

