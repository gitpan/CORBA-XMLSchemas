use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'CORBA::XMLSchemas',
    'VERSION_FROM'  => 'xsd.pm',
    'ABSTRACT'      => 'IDL compiler to WSDL/SOAP and W3C Schema',
    'PREREQ_PM'     => {
                        'CORBA::IDL::node'  => 2.04,
    },
    'PM'            => {
                        'xsd.pm'        => '$(INST_LIBDIR)/XMLSchemas/xsd.pm',
                        'xsdname.pm'    => '$(INST_LIBDIR)/XMLSchemas/xsdname.pm',
                        'wsdl.pm'       => '$(INST_LIBDIR)/XMLSchemas/wsdl.pm',
                        'rng.pm'        => '$(INST_LIBDIR)/XMLSchemas/rng.pm',
    },
    'EXE_FILES'     => ['idl2xsd.pl', 'idl2wsdl.pl', 'idl2soap.pl', 'idl2rng.pl'],
    'AUTHOR'        => "Francois PERRAD (francois.perrad\@gadz.org)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);
