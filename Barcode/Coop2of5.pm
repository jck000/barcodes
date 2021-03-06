package Barcode::Coop2of5;

# Barcode generation classes
#
# Copyright 2003 Michael Chaney Consulting Corporation
# Written by: Michael Chaney
#
# See enclosed documentation for full copyright and contact information

use strict;
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Carp qw(croak);

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = '0.05';

=head1 NAME

Barcode::Coop2of5 - Create pattern for Coop 2 of 5

=head1 SYNOPSIS

    use Barcode::Coop2of5;
    
    my $bc = new Barcode::Coop2of5;
	 my $text = '123459';
	 my $checkdigit = $bc->checkdigit($text);
	 my $pattern = $bc->barcode($text.$checkdigit);

	 print $pattern,"\n";

=head1 DESCRIPTION

Barcode::Coop2of5 creates the patterns that you need to display
Coop 2 of 5 barcodes.  The pattern returned is a string of 1's and 0's,
where 1 represent part of a black bar and 0 represents a space.  Each
character is a single unit wide, so "111001" is a black bar 3 units wide, a
space two units wide, and a black bar that is one unit wide.  It is up to the
programmer to create code to display the resultant barcode.

=head1 PREREQUISITES

This module requires C<strict>, C<Exporter>, and C<Carp>.

=head2 EXPORT

None.

=cut

# 7 4 2 1 P - encodes bars and spaces
my %patterns = (
	'(' => 'wnw',
	'0' => 'wwnnn',
	'1' => 'nnnww',
	'2' => 'nnwnw',
	'3' => 'nnwwn',
	'4' => 'nwnnw',
	'5' => 'nwnwn',
	'6' => 'nwwnn',
	'7' => 'wnnnw',
	'8' => 'wnnwn',
	'9' => 'wnwnn',
	')' => 'nww'
);

=head1 CONSTRUCTOR

=over 4

=item C<new(options)>

Create a new Barcode::Coop2of5 object. The different options that can
be set are:

=over 4

=item addcheck

Automatically add a check digit to each barcode

=item barchar

Character to represent bars (defaults to '1')

=item spacechar

Character to represent spaces (defaults to '0')

=back

Example:

	 $bc = new Barcode::Coop2of5(addcheck => 1);

    Create a new Coop 2/5 barcode object that will automatically add check digits.

=back

=cut


sub new {

  my ($class, %opts) = @_;
  my $self = {
    addcheck => 0,
	 barchar => '1',
	 spacechar => '0',
	 wnstr => '',
	 barcode_type => 'Coop 2 of 5',
  };

  foreach (keys %opts) {
    $self->{$_} = $opts{$_};
  }

  bless $self, $class;

  return $self;
}

=head1 OBJECT METHODS

All methods simply croak on errors.  The only error that can occur here is
trying to encode a non-digit.

=over 4

=item C<checkdigit(number)>

Generates the check digit for a number.  There is no possibility of failure
if you assure that only digits are passed in, as there is no other failure
scenario.

Example:

	print $bc->checkdigit('435'),"\n";

	Prints a single 0

=cut


sub checkdigit {

  my $self = shift;
  my $str = shift;
  my $a=0;
  
  if (!$self->validate($str)) {
    croak("Invalid $self->{barcode_type} data: >> $str <<");
  }

  my @str=split(//, $str);

  my $weight=1;  # weight is 1 for even positions, 3 for odd positions

  while (@str) {
    my $digit = pop(@str);
    $a += $digit * $weight;
    $weight = 4 - $weight;
  }

  return ((10-($a%10))%10);
}


=item C<barcode(number)>

Creates the pattern for this number.  If the C<addcheck> option was set, then
the check digit will be computed and appended automatically.  The pattern will
use C<barchar> and C<spacechar> to represent the bars and spaces.  As a side
effect, the "wnstr" property is set to a string of w's and n's to represent the
barcode.

If the string that is passed in contains a non-digit, it will croak.

=cut


sub barcode {

  my $self = shift;
  my $str = shift;
  
  if (!$self->validate($str)) {
    croak("Invalid $self->{barcode_type} data: >> $str <<");
  }

  if ($self->{'addcheck'}) {
	 $str .= $self->checkdigit($str);
  } else {
    if (!$self->validate_checksum($str)) {
      croak("Invalid checksum for $self->{barcode_type} >>$str<<");
    }
  }

  my $wnstr = '(' . $str . ')';

  $wnstr =~ s/(.)/$patterns{$1}.'n'/eg;
  chop($wnstr);

  # At this point, $wnstr is a string of w's and n's, representing wide
  # (2 units) and narrow (1 unit). As is standard, the first character
  # is a bar, then it alternates between spaces and bars.

  my $retstr;
  my $outdigit;
  for (my $i=0 ; $i<length($wnstr) ; $i++) {
    if ($i&1) {   $outdigit=$self->{'spacechar'};
	 } else {      $outdigit=$self->{'barchar'};
	 }
    if (substr($wnstr,$i,1) eq 'w') {
      $retstr .= ($outdigit x 2);
	 } else {
      $retstr .= $outdigit;
	 }
  }

  $self->{'wnstr'} = $wnstr;

  return $retstr;
}

=item C<barcode_rle(string)>

Creates a run-length-encoded (RLE) barcode definition for the given string.
It consists of a width (in units) of the entire code, followed by a colon,
then followed by the RLE string.  The RLE string consists of digits which
alternately refer to the width of a black bar and a white space.  The RLE
string always starts with a black bar.

As an example, consider "38" in Code11 as an RLE string:

29:112211221112112111221

It will render as:

# ##  # ##  # #  # ## # ##  #

The point is not to save space, as there isn't much of a savings to be had.
Rather, it is far easier to write code to render the RLE format.

=cut

sub barcode_rle {

  my $self = shift;
  my $str = shift;
  
  my $pattern=$self->barcode($str);

  my $retstr=sprintf('%d:%s', length($pattern), $self->{'wnstr'});

  $retstr =~ tr/wn/21/;

  return $retstr;
}


=item C<validate(string)>

The validate method simply returns true if the given string can be encoded
in this barcode type or false if not.  In most of the modules, validate
also verifies the checksum, however, Codabar doesn't have a consistent
checksum scheme (nor does it need one) so we don't check it.


=cut

sub validate {

  my $self = shift;
  my $str = shift;
  
  return ($str=~/^\d+$/);
}

=item C<validate_checksum(string)>

Returns true if the checksum encoded in the string is correct, false
otherwise.

=cut

sub validate_checksum {

  my $self = shift;
  my $str = shift;

  if (!$self->validate($str)) {
    croak("Invalid $self->{barcode_type} data: >> $str <<");
  }

  my ($payload, $checkme, $checkdigit);

  ($payload, $checkme) = ($str =~/^(.*)(.)$/);

  $checkdigit = $self->checkdigit($payload);

  return ($checkdigit eq $checkme);
}


=back

=head1 BUGS

Untested!  My barcode scanner doesn't recognize these, although they match
up with samples from the internet.

=head1 AUTHOR

Michael Chaney mdchaney@michaelchaney.com
Michael Chaney Consulting Corporation http://www.michaelchaney.com/

=head1 COPYRIGHT

Copyright (C) 2003, Michael Chaney Consulting Corporation
All rights not explicitly granted herein are reserved
You may distribute under any of the following three licenses:
GNU General Public License
Coop BSD license
Artistic License


=head1 SEE ALSO

L<Barcode>, L<Barcode::Interleaved2of5>

=cut

1;
