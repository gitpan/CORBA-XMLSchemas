#!/usr/bin/perl -w

use strict;
use CORBA::IDL::parser30;
use CORBA::IDL::symbtab;
# visitors
use CORBA::XMLSchemas::xsdname;
use CORBA::XMLSchemas::xsd;
use CORBA::XMLSchemas::wsdl;
use CORBA::XMLSchemas::rng;

my $parser = new Parser;
$parser->YYData->{verbose_error} = 1;		# 0, 1
$parser->YYData->{verbose_warning} = 1;		# 0, 1
$parser->YYData->{verbose_info} = 1;		# 0, 1
$parser->YYData->{verbose_deprecated} = 0;	# 0, 1 (concerns only version '2.4' and upper)
$parser->YYData->{symbtab} = new CORBA::IDL::Symbtab($parser);
my $cflags = '-D__idl2wsdl';
if ($Parser::IDL_version lt '3.0') {
	$cflags .= ' -D_PRE_3_0_COMPILER_';
}
if ($^O eq 'MSWin32') {
	$parser->YYData->{preprocessor} = 'cpp -C ' . $cflags;
#	$parser->YYData->{preprocessor} = 'CL /E /C /nologo ' . $cflags;	# Microsoft VC
} else {
	$parser->YYData->{preprocessor} = 'cpp -C ' . $cflags;
}
$parser->getopts("b:hi:s:vx");
if ($parser->YYData->{opt_v}) {
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
	if (exists $parser->YYData->{opt_s} and $parser->YYData->{opt_s} eq "rng") {
		$parser->YYData->{root}->visit(new CORBA::XMLSchemas::relaxngVisitor($parser));
	} else {
		$parser->YYData->{root}->visit(new CORBA::XMLSchemas::xsdVisitor($parser));
	}
	$parser->YYData->{root}->visit(new CORBA::XMLSchemas::wsdlVisitor($parser, $parser->YYData->{opt_s}));
	$parser->YYData->{root}->visit(new CORBA::XMLSchemas::wsdlSoapBindingVisitor($parser));
}

__END__

=head1 NAME

idl2soap - IDL compiler to WSDL/SOAP (Web Services Description Language)

=head1 SYNOPSIS

idl2soap [options] I<spec>.idl

=head1 OPTIONS

All options are forwarded to C preprocessor, except -b -h -i -s -v -x.

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

Specify a base uri for location of import.

=item B<-h>

Display help.

=item B<-i> I<directory>

Specify a path for import (only for IDL version 3.0).

=item B<-s> (I<xsd>|I<rng>)

Specify the schema used. By default I<xsd>.

=item B<-v>

Display version.

=item B<-x>

Enable export (only for IDL version 3.0).

=back

=head1 DESCRIPTION

B<idl2soap> parses the given input file (IDL) and generates :

=over 4

=item *
a W3C Schema I<spec>.xsd following the CORBA to WSDL/SOAP Interworking
Specification (WS-I comformant soap binding).

=item *
a WSDL file I<spec>.wsdl (WS-I comformant soap binding).

=item *
a WSDL binding file I<spec>binding.wsdl (WS-I comformant soap binding).

=back

B<idl2soap> is a Perl OO application what uses the visitor design pattern.
The parser is generated by Parse::Yapp.

B<idl2soap> needs XML::DOM module.

B<idl2soap> needs a B<cpp> executable.

CORBA Specifications, including IDL (Interface Definition Language) and
CORBA to WSDL/SOAP Interworking Specification are
available on E<lt>http://www.omg.org/E<gt>.

WSDL 1.1 (Web Services Description Language) specifications
are available on E<lt>http://www.w3.org/TR/wsdlE<gt>.

=head1 SEE ALSO

cpp, perl, idl2html, idl2java, idl2xsd, idl2rng, idl2wsdl

=head1 COPYRIGHT

(c) 2003-2004 Francois PERRAD, France. All rights reserved.

This program and all CORBA::XMLSchemas modules are distributed
under the terms of the Artistic Licence.

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

