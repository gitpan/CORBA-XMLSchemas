#!/usr/bin/perl -w

use strict;
use CORBA::IDL::parser30;
use CORBA::IDL::symbtab;
# visitors
use CORBA::XMLSchemas::xsdname;
use CORBA::XMLSchemas::rng;

my $parser = new Parser;
$parser->YYData->{verbose_error} = 1;		# 0, 1
$parser->YYData->{verbose_warning} = 1;		# 0, 1
$parser->YYData->{verbose_info} = 1;		# 0, 1
$parser->YYData->{verbose_deprecated} = 0;	# 0, 1 (concerns only version '2.4' and upper)
$parser->YYData->{symbtab} = new CORBA::IDL::Symbtab($parser);
my $cflags = '-D__idl2rng';
if ($Parser::IDL_version lt '3.0') {
	$cflags .= ' -D_PRE_3_0_COMPILER_';
}
if ($^O eq 'MSWin32') {
	$parser->YYData->{preprocessor} = 'cpp -C ' . $cflags;
#	$parser->YYData->{preprocessor} = 'CL /E /C /nologo ' . $cflags;	# Microsoft VC
} else {
	$parser->YYData->{preprocessor} = 'cpp -C ' . $cflags;
}
$parser->getopts("b:hi:qr:stvx");
if ($parser->YYData->{opt_v}) {
	use CORBA::XMLSchemas::xsd;
	print "CORBA::XMLSchemas $CORBA::XMLSchemas::xsd::VERSION\n";
	print "CORBA::IDL $CORBA::IDL::node::VERSION\n";
	print "IDL $Parser::IDL_version\n";
	print "$0\n";
	print "Perl $] on $^O\n";
	exit;
}
if ($parser->YYData->{opt_h}) {
	use Pod::Usage;
	pod2usage(-verbose => 1);
}
$parser->Run(@ARGV);
$parser->YYData->{symbtab}->CheckForward();
$parser->YYData->{symbtab}->CheckRepositoryID();

if (exists $parser->YYData->{nb_error}) {
	my $nb = $parser->YYData->{nb_error};
	print "$nb error(s).\n"
}
if (        $parser->YYData->{verbose_warning}
		and exists $parser->YYData->{nb_warning} ) {
	my $nb = $parser->YYData->{nb_warning};
	print "$nb warning(s).\n"
}
if (        $parser->YYData->{verbose_info}
		and exists $parser->YYData->{nb_info} ) {
	my $nb = $parser->YYData->{nb_info};
	print "$nb info(s).\n"
}
if (        $parser->YYData->{verbose_deprecated}
		and exists $parser->YYData->{nb_deprecated} ) {
	my $nb = $parser->YYData->{nb_deprecated};
	print "$nb deprecated(s).\n"
}

if (        exists $parser->YYData->{root}
		and ! exists $parser->YYData->{nb_error} ) {
	if (        $Parser::IDL_version ge '3.0'
			and $parser->YYData->{opt_x} ) {
		$parser->YYData->{symbtab}->Export();
	}
	$parser->YYData->{root}->visit(new CORBA::XMLSchemas::nameVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::XMLSchemas::relaxngVisitor($parser, $parser->YYData->{opt_s}, $parser->YYData->{opt_r}));
}

__END__

=head1 NAME

idl2rng - IDL compiler to RELAX NG Schema

=head1 SYNOPSIS

idl2rng [options] I<spec>.idl

=head1 OPTIONS

All options are forwarded to C preprocessor, except -b -h -i -q -r -s -t -v -x.

With the GNU C Compatible Compiler Processor, useful options are :

=over 8

=item B<-D> I<name>

=item B<-D> I<name>=I<definition>

=item B<-I> I<directory>

=item B<-I->

=item B<-nostdinc>

=back

Specific options :

=over 8

=item B<-b> I<base uri>

Specify a base uri for location of include.

=item B<-h>

Display help.

=item B<-i> I<directory>

Specify a path for import (only for IDL version 3.0).

=item B<-q>

Generate qualified elements.

=item B<-r> I<root-element>

Specify a root element.

=item B<-s>

Generate a standalone Schema (not only type definition).

=item B<-t>

Generate tabulated XML (beautify for human).

=item B<-v>

Display version.

=item B<-x>

Enable export (only for IDL version 3.0).

=back

=head1 DESCRIPTION

B<idl2rng> parses the given input file (IDL) and generates :

=over 4

=item *
a RELAX NG Schema I<spec>.rng equivalent to W3C Schema following the CORBA
to WSDL/SOAP Interworking Specification (WS-I comformant soap binding).

=back

B<idl2rng> is a Perl OO application what uses the visitor design pattern.
The parser is generated by Parse::Yapp.

B<idl2rng> needs XML::DOM module.

B<idl2rng> needs a B<cpp> executable.

CORBA Specifications, including IDL (Interface Definition Language) and
CORBA to WSDL/SOAP Interworking Specification are
available on E<lt>http://www.omg.org/E<gt>.

=head1 SEE ALSO

cpp, perl, idl2html, idl2javaxml, idl2xsd

=head1 COPYRIGHT

(c) 2003-2005 Francois PERRAD, France. All rights reserved.

This program and all CORBA::XMLSchemas modules are distributed
under the terms of the Artistic Licence.

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

