# Copyright (c) 2002 Anders Johnson. All rights reserved. This program is free
# software; you can redistribute it and/or modify it under the same terms as
# Perl itself. The author categorically disclaims any liability for this
# software.

=head1 NAME

Math::Business::BlackScholes - Black-Scholes option price model functions

=head1 SYNOPSIS

	use Math::Business::BlackScholes qw/call_price call_put_prices/;

	my $call=call_price(
	  $current_market_price, $volatility, $strike_price,
	  $remaining_term, $interest_rate, $fractional_yield
	);

	my $put=Math::Business::BlackScholes::put_price(
	  $current_market_price, $volatility, $strike_price,
	  $remaining_term, $interest_rate
	); # $fractional_yield defaults to 0.0

	my ($c, $p)=call_put_prices(
	  $current_market_price, $volatility, $strike_price,
	  $remaining_term, $interest_rate, $fractional_yield
	);

=head1 DESCRIPTION

Estimates the fair market price of a European stock option
according to the Black-Scholes model.

call_price() returns the price of a call option.
put_price() returns the value of a put option.
call_put_prices() returns a 2-element array whose first element is the price
of a call option, and whose second element is the price of the put option
with the same parameters; it is expected to be computationally more efficient
than calling call_price() and put_price() sequentially with the same arguments.
Each of these routines accepts the same set of parameters:

C<$current_market_price> is the price for which the underlying security is
currently trading.
C<$volatility> is the standard deviation of the probability distribution of
the natural logarithm of the stock price one year in the future.
C<$strike_price> is the strike price of the option.
C<$remaining_term> is the time remaining until the option expires, in years.
C<$interest_rate> is the risk-free interest rate (per year).
C<$fractional_yield> is the fraction of the stock price that the stock
yields in dividends per year; it is assumed to be zero if unspecified.

=head2 Determining Parameter Values

C<$volatility> and C<$fractional_yield> are traditionally estimated based on
historical data.
C<$interest_rate> is traditionally equal to the current T-bill rate.
The model assumes that these parameters are stable over the term of the
option.

=head2 American Options

Whereas a European stock option may be exercised only when it expires,
an American option may be exercised any time prior to its expiration.
The price of an American option is usually the same as
the price of the corresponding European option, because the expected value
of an option is almost always greater than its intrinsic value.
However, if the dividend yield (in the case of a call option) or interest
rate (in the case of a put option) is high, or if there are
tax considerations related to the timing of the exercise, then an American
option may be more valuable to the holder.

=head2 Negative Market Value

An underlying security with a negative market value is assumed to be a short.
Buying a short is equivalent to selling the security, so a call option on
a short is equivalent to a put option.
This is somewhat confusing, and arguably a warning ought to be generated if
it gets invoked.

=head1 DIAGNOSTICS

Attempting to evaluate an option with a negative term will result in a croak(),
because that's meaningless.
Passing suspicious arguments (I<e.g.> a negative interest rate) will result
in descriptive warning messages.
To disable such messages, try this:

	{
		local($SIG{__WARN__})=sub{};
		$value=call_price( ... );
	}

=head1 CAVEATS

=over 2

=item *

This module requires C<Math::CDF>.

=item *

The model assumes that dividends are distributed continuously.
In reality, the timing of the distribution relative to the current time
and the option expiration time can affect the option price by as much as
the value of a single dividend.

=item *

The fractional computational error of call_price() is usually negligible.
However, while the computational error of put_price() is typically small
in comparison to the current market price, it might be significant in
comparison to the result.
That's probably unimportant for most purposes.
(To correct this problem would require increasing both complexity and
execution time.)

=item *

The author categorically disclaims any liability for this module.

=back

=head1 BUGS

=over 2

=item *

The length of the namespace component "BlackScholes" is said to cause
unspecified portability problems for DOS and other 8.3 filesystems,
but the consensus of the Perl community was that it is more important
to have a descriptive name.

=back

=head1 SEE ALSO

L<Math::CDF|Math::CDF>

=head1 AUTHOR

Anders Johnson <F<anders@ieee.org>>

=cut

package Math::Business::BlackScholes;

use strict;

BEGIN {
	use Exporter;
	use vars qw/$VERSION @ISA @EXPORT_OK/;
	$VERSION = 0.02;
	@ISA = qw/Exporter/;
	@EXPORT_OK = qw/call_price put_price call_put_prices/;
}

use Math::CDF qw/pnorm/;
use Carp;

# Don't call this directly -- it might change without notice
sub _precompute {
	@_<5 && carp("Too few arguments");
	my ($market, $sigma, $strike, $term, $interest, $yield)=@_;
	$yield=0.0 unless defined $yield;

	$market>=0.0 || croak("Negative market price");
	if($sigma<0.0) {
		carp("Negative volatility (using absolute value instead)");
		$sigma=-$sigma;
	}
	$strike>=0.0 || carp("Negative strike price");
	$term>=0.0 || croak("Negative remaining term");
	$interest>=0.0 || carp("Negative interest rate");
	$yield>=0.0 || carp("Negative yield");
	@_>6 && carp("Ignoring additional arguments");

	my $seyt=$market * exp(-$yield * $term);
	my $xert=$strike * exp(-$interest * $term);
	my $nd1;
	my $nd2;
	if($sigma==0.0 || $term==0.0 || $market==0.0 || $strike<=0.0) {
		if($seyt > $xert) {
			$nd1=1.0;
			$nd2=1.0;
		}
		else {
			$nd1=0.0;
			$nd2=0.0;
		}
	}
	else {
		my $ssrt=$sigma * sqrt($term);
		my $d1=(
		  log($market / $strike) +
		  ($interest - $yield + $sigma*$sigma/2.0)*$term
		) / $ssrt;
		my $d2=$d1 - $ssrt;
		$nd1=pnorm($d1);
		$nd2=pnorm($d2);
	}
	return ($seyt, $nd1, $xert, $nd2);
}

sub call_price {
	if($_[0]<0.0) {
		return put_price(-$_[0], $_[1], -$_[2], @_[3..$#_]);
	}
	my ($seyt, $nd1, $xert, $nd2) = _precompute(@_);
	return $seyt*$nd1 - $xert*$nd2;
}

sub put_price {
	if($_[0]<0.0) {
		return call_price(-$_[0], $_[1], -$_[2], @_[3..$#_]);
	}
	my ($seyt, $nd1, $xert, $nd2) = _precompute(@_);
	return $seyt*($nd1 - 1.0) - $xert*($nd2 - 1.0);
}

sub call_put_prices {
	if($_[0]<0.0) {
		my ($put, $call)=call_put_prices(
		  -$_[0], $_[1], -$_[2], @_[3..$#_]
		);
		return ($call, $put);
	}
	my ($seyt, $nd1, $xert, $nd2) = _precompute(@_);
	my $call=$seyt*$nd1 - $xert*$nd2;
	return ($call, $call - $seyt + $xert);
}

1;

